defmodule PicselloWeb.Live.Pricing.Calculator.Index do
  use PicselloWeb, live_view: [layout: "calculator"]

  alias Picsello.{Repo, JobType, PricingCalculations}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_step(1)
    |> then(fn %{assigns: %{current_user: user}} = socket ->
      assign(socket,
        pricing_calculations: %PricingCalculations{
          organization_id: user.organization_id,
          job_types: user.organization.profile.job_types,
          state: user.onboarding.state,
          min_years_experience: user.onboarding.photographer_years,
          schedule: user.onboarding.schedule,
          self_employment_tax_percentage: tax_schedule().self_employment_percentage,
          desired_salary: Money.new(0)
        }
      )
    end)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_params(params, _session, socket) do
    step = Map.get(params, "step", "1") |> String.to_integer()
    category_id = Map.get(params, "category_id", "1") |> String.to_integer()

    if step == 6 do
      socket
      |> assign_cost_category_step(category_id)
      |> assign_changeset()
      |> noreply()
    else
      socket
      |> assign_step(step)
      |> assign_changeset()
      |> noreply()
    end
  end

  @impl true
  def handle_event("next", _, %{assigns: %{step: step}} = socket) do
    socket
    |> assign_step(step + 1)
    |> assign_changeset()
    |> push_patch(to: Routes.calculator_path(socket, :index, %{step: step + 1}))
    |> noreply()
  end

  @impl true
  def handle_event("previous", _, %{assigns: %{step: step}} = socket) do
    socket
    |> assign_step(step - 1)
    |> assign_changeset()
    |> push_patch(to: Routes.calculator_path(socket, :index, %{step: step - 1}))
    |> noreply()
  end

  @impl true
  def handle_event("exit", _, socket) do
    socket
    |> push_redirect(to: Routes.home_path(socket, :index), replace: true)
    |> noreply()
  end

  @impl true
  def handle_event("edit-cost", params, socket) do
    category_id = Map.get(params, "id", "1") |> String.to_integer()

    socket
    |> push_patch(
      to: Routes.calculator_path(socket, :index, %{step: 6, category_id: category_id})
    )
    |> noreply()
  end

  @impl true
  def handle_event("edit-cost-back", _, socket) do
    socket
    |> assign_step(4)
    |> push_patch(to: Routes.calculator_path(socket, :index, %{step: 4}))
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"pricing_calculations" => params}, socket) do
    socket
    |> assign_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"pricing_calculations" => params},
        %{assigns: %{step: step}} = socket
      ) do
    case socket |> build_changeset(params) |> Repo.insert_or_update() do
      {:ok, pricing_calculations} ->
        socket
        |> assign(pricing_calculations: pricing_calculations)
        |> assign_step(step + 1)
        |> assign_changeset()
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"calculator-step-#{@step}"}>
      <.step {assigns} f={f} />
    </.form>
    """
  end

  defp step(%{step: 2} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">We need to know a little about what you do currently in order to build accurate results.</h4>

        <% input_name = input_name(@f, :job_types) <> "[]" %>
        <div class="flex flex-col pb-1">
          <p class="py-2 font-extrabold">
            What’s your speciality?
            <i class="italic font-light">(Select one or more)</i>
          </p>

          <div class="mt-2 grid grid-cols-3 gap-3 sm:gap-5">
            <%= for(job_type <- job_types(), checked <- [Enum.member?(input_value(@f, :job_types) || [], job_type)]) do %>
              <.job_type_option type="checkbox" name={input_name} job_type={job_type} checked={checked} />
            <% end %>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3 sm:gap-5">
            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">Are you a full-time or part-time photographer?</p>

              <%= select @f, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select p-4" %>
            </label>

            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">How many years have you been a photographer?</p>

              <%= input @f, :min_years_experience, type: :number_input, phx_debounce: 500, min: 0, placeholder: "22", class: "p-4" %>
              <%= error_tag @f, :min_years_experience, class: "text-red-sales-300 text-sm" %>
            </label>
          </div>

          <div class="grid grid-cols-2 gap-3 sm:gap-5">
            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">What's your zipcode?</p>

              <%= input @f, :zipcode, type: :text_input, phx_debounce: 500, min: 0, placeholder: "12345", class: "p-4" %>
              <%= error_tag @f, :zipcode, class: "text-red-sales-300 text-sm" %>
            </label>

            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">Where’s your business based?</p>

              <%= select @f, :state, [{"select one", nil}] ++ @states, class: "select p-4" %>
              <%= error_tag @f, :state, class: "text-red-sales-300 text-sm" %>
            </label>
          </div>

        <div class="flex justify-end mt-8">
          <button type="submit" class="btn-primary">Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 3} = assigns) do
    desired_salary = input_value(assigns.f, :desired_salary)
    tax_bracket = PricingCalculations.get_income_bracket(desired_salary)
    after_tax_income = PricingCalculations.calculate_after_tax_income(tax_bracket, desired_salary)

    take_home =
      PricingCalculations.calculate_take_home_income(
        assigns.pricing_calculations.self_employment_tax_percentage,
        after_tax_income
      )

    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">Let us know how much time you spend and how much you’d like to make.</h4>
        <p class="py-2 font-extrabold">What does your average weekly dedication look like for your photography business? <span class="italic font-normal">(include all marketing, client communications, shoots, editing, travel, weekends, prep, etc)</span></p>
        <div class="flex w-full mb-8 mt-4">
          <div class="w-1/3">
            <label class="flex flex-col border-r-2">
              <p class="pb-2">My average time each week is:</p>
              <div class="flex items-center">
                <%= input @f, :average_time_per_week, type: :text_input, phx_debounce: 500, min: 0, placeholder: "40", class: "p-4 w-24 text-center" %>
                <%= error_tag @f, :average_time_per_week, class: "text-red-sales-300 text-sm" %>
                <span class="font-bold ml-4">hours</span>
              </div>
            </label>
          </div>
          <div class="w-2/3 pl-12">
            <label class="flex flex-col">
              <p class="pb-2">I frequently work the following days:</p>
              <div class="mt-2 flex flex-wrap">
              <% input_name = input_name(@f, :average_days_per_week) <> "[]" %>
              <%= for(day <- days(), checked <- [Enum.member?(input_value(@f, :average_days_per_week) || [], day)]) do %>
                <.day_option type="checkbox" name={input_name} day={day} checked={checked} />
              <% end %>
            </div>
            </label>
          </div>
        </div>
        <p class="py-2 font-extrabold">How much do you want to take home a year after taxes? <span class="italic font-normal">(including healthcare costs)</span></p>
        <div class="max-w-md" {intro_hints_only("intro_hints_only")}>
          <label class="flex items-center justify-between mt-4">
            <p class="font-extrabold">Annual Desired Salary</p>
            <%= input @f, :desired_salary, type: :text_input, phx_debounce: 0, min: 0, placeholder: "$60,000", class: "p-4 w-40 text-center" %>
            <%= error_tag @f, :desired_salary, class: "text-red-sales-300 text-sm" %>
          </label>
          <hr class="mt-4 mb-4" />
          <div class="flex items-center justify-between">
            <p class="font-extrabold">Approximate Tax Bracket <br /> <span class="font-normal italic">How did you calculate this? <.intro_hint content="Based on the salary you entered, we looked at what the IRS has listed as the percentage band of income you are in." class="ml-1" /></span></p>
            <%= hidden_input(@f, :tax_bracket, value: tax_bracket.percentage ) %>
            <p class="w-40 text-center font-bold"><%= tax_bracket.percentage %>%</p>
          </div>
          <hr class="mt-4 mb-4" />
          <div class="flex items-center justify-between">
            <p class="font-extrabold py-2">Approximate After Income Tax <br /> <span class="font-normal italic">How did you calculate this? <.intro_hint content="Using the formula found here. We calculated the amount of income you would receive after taxes." class="ml-1" /></span></p>
            <%= hidden_input(@f, :after_income_tax, value: after_tax_income ) %>
            <p class="w-40 text-center font-bold"><%= after_tax_income %></p>
          </div>
          <hr class="mt-4 mb-4" />
          <div class="flex items-center justify-between">
            <p class="font-extrabold py-2">Self-employment tax <br /> <span class="font-normal italic">What's this? <.intro_hint content="Since you are technically self-employed, the IRS has a special tax percentage this is calculate after your normal income tax. There is no graduation here, just straight 15.3%." class="ml-1" /></span></p>
            <p class="w-40 text-center font-bold"><%= @pricing_calculations.self_employment_tax_percentage %>%</p>
          </div>
          <hr class="mt-4 mb-4" />
          <div class="flex items-center justify-between">
            <p class="font-extrabold py-2">Approximate After Income Tax</p>
            <%= hidden_input(@f, :take_home, value: take_home ) %>
            <p class="w-40 text-center font-bold"><%= take_home %></p>
          </div>
        </div>
        <div class="flex justify-end mt-8">
          <button type="button" class="btn-secondary mr-4" phx-click="previous">Back</button>
          <button type="submit" class="btn-primary">Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 4} = assigns) do
    IO.inspect(cost_categories())

    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">All businesses have costs. Lorem ipsum dolor sit amet content here.</h4>
        <p class="italic">(We’ll provide you a rough estimate on what these should cost you by what you’ve answered so far. You can go in tweak what you need.)</p>
        <.financial_review />
        <h4 class="text-2xl font-bold mb-4">Cost categories</h4>
        <ul>
          <% input_name = input_name(@f, :cost_categories) <> "[]" %>
          <%= for(%Picsello.PricingCalculatorBusinessCosts{} = cost_category <- cost_categories(), checked <- [Enum.member?(input_value(@f, :cost_categories) || [], cost_category)]) do %>
            <.category_option type="checkbox" name={input_name} checked={checked} cost_category={cost_category} />
          <% end %>
        </ul>
        <div class="flex justify-end mt-8">
          <button type="button" class="btn-secondary mr-4" phx-click="previous">Back</button>
          <button type="button" class="btn-primary" phx-click="next">Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 5} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">Based on what you told us—we’ve calculated some suggestions on how much to charge and how many shoots you should do.</h4>
        <p>Lorem ipsum talk about how they can contact us for business advice here.</p>
        <h4 class="text-2xl font-bold mb-4">Financial Summary</h4>
        <.financial_review />
        <div class="flex justify-end mt-8">
          <button type="button" class="btn-secondary mr-4" phx-click="previous">Back</button>
          <button type="button" class="btn-primary">Save Results</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 6} = assigns) do
    ~H"""
      <.container {assigns}>
        <table class="responsive-table w-full">
          <thead>
            <tr>
              <th class="text-left font-bold border-b-4 border-blue-planning-300 text-lg pb-2 py-4">Item</th>
              <th class="text-left font-bold border-b-4 border-blue-planning-300 text-lg pb-2 py-4">Your Cost Monthy</th>
              <th class="text-left font-bold border-b-4 border-blue-planning-300 text-lg pb-2 py-4">Your Cost Yearly</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="p-4">Equipment<br/>(repair, replacement, etc)</td>
              <td class="p-4">$83.33<span class="text-blue-planning-300 border-b-1 border-blue-planning-300 border-dotted">/month</span></td>
              <td class="p-4">
                <%= input @f, :category_cost, type: :text_input, phx_debounce: 500, min: 0, placeholder: "$500", class: "p-4 w-40 text-center" %>
                <%= error_tag @f, :category_cost, class: "text-red-sales-300 text-sm" %>
                <span class="text-blue-planning-300 border-b-1 border-blue-planning-300 border-dotted">/year</span>
              </td>
            </tr>
            <tr>
              <td class="p-4">Equipment<br/>(repair, replacement, etc)</td>
              <td class="p-4">$83.33<span class="text-blue-planning-300 border-b-1 border-blue-planning-300 border-dotted">/month</span></td>
              <td class="p-4">
                <%= input @f, :category_cost, type: :text_input, phx_debounce: 500, min: 0, placeholder: "$500", class: "p-4 w-40 text-center" %>
                <%= error_tag @f, :category_cost, class: "text-red-sales-300 text-sm" %>
                <span class="text-blue-planning-300 border-b-1 border-blue-planning-300 border-dotted">/year</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div class="flex justify-end mt-8">
          <button type="button" class="btn-secondary mr-4" phx-click="edit-cost-back">Back</button>
        </div>
      </.container>
    """
  end

  defp step(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center w-screen min-h-screen p-5 bg-gray-100 relative">
      <div class="circleBtn absolute top-8 left-8">
        <ul>
          <li>
              <a href="javascript:void(0); history.back()">
                <.icon name="back" class="w-14 h-14 stroke-current text-blue-planning-300 rounded-full" />
                <span class="overflow-hidden">Exit calculator</span>
              </a>
          </li>
        </ul>
      </div>
      <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48 mb-10" />
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <h1 class="md:text-6xl text-4xl font-bold mb-10">Pricing <span class="md:border-b-8 border-b-4 border-blue-planning-300">Calculator</span></h1>
        <p class="text-xl mb-4">You probably aren’t charging enough and we’d like to help. We have 4 sections for you to fill out to calculate what you should be charging </p>
        <ul class="flex flex-wrap columns-2">
          <li class="flex items-center mb-2 md:w-1/2 w-full"><span class="bg-blue-planning-300 text-white w-8 h-8 inline-block flex items-center justify-center mr-2 rounded-full">1</span>Information about your business</li>
          <li class="flex items-center mb-2 md:w-1/2 w-full"><span class="bg-blue-planning-300 text-white w-8 h-8 inline-block flex items-center justify-center mr-2 rounded-full">2</span>Financial & time goals</li>
          <li class="flex items-center mb-2 md:w-1/2 w-full"><span class="bg-blue-planning-300 text-white w-8 h-8 inline-block flex items-center justify-center mr-2 rounded-full">3</span>Business costs</li>
          <li class="flex items-center mb-2 md:w-1/2 w-full"><span class="bg-blue-planning-300 text-white w-8 h-8 inline-block flex items-center justify-center mr-2 rounded-full">4</span>Results</li>
        </ul>
        <div class="flex justify-end mt-8">
          <a href="javascript:void(0); history.back()" class="btn-secondary inline-block mr-4">Go Back</a>
          <button type="button" class="btn-primary" phx-click="next">Get started</button>
        </div>
      </div>
    </div>
    """
  end

  defp assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      step_title: "Information about your business",
      page_title: "Pricing Calculator step 1"
    )
    |> assign_new(:states, &states/0)
  end

  defp assign_step(socket, 3) do
    socket
    |> assign(
      step: 3,
      step_title: "Financial & time goals",
      page_title: "Pricing Calculator step 2"
    )
  end

  defp assign_step(socket, 4) do
    socket
    |> assign(
      step: 4,
      step_title: "Business costs",
      page_title: "Pricing Calculator step 3"
    )
  end

  defp assign_step(socket, 5) do
    socket
    |> assign(
      step: 5,
      step_title: "Results",
      page_title: "Pricing Calculator step 4"
    )
  end

  defp assign_step(socket, 6) do
    socket
    |> assign(
      step: 6,
      step_title: "Edit business cost",
      page_title: "Edit business cost"
    )
  end

  defp assign_step(socket, _) do
    socket
    |> assign(
      step: 1,
      step_title: "Tell us more about yourself",
      page_title: "Pricing Calculator"
    )
  end

  defp build_changeset(
         %{assigns: %{pricing_calculations: pricing_calculations}},
         params,
         action \\ nil
       ) do
    PricingCalculations.changeset(
      pricing_calculations,
      params
    )
    |> Map.put(:action, action)
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  defp assign_cost_category_step(socket, category_id) do
    socket
    |> assign(
      step: 6,
      step_title: category_id |> Integer.to_string(),
      page_title: category_id |> Integer.to_string()
    )
  end

  def day_option(assigns) do
    assigns = Enum.into(assigns, %{disabled: false, class: ""})

    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:bg-blue-planning-100 hover:bg-opacity-60 cursor-pointer font-semibold text-sm leading-tight sm:text-base w-12 flex items-center justify-center mr-4 #{@class}",
        %{"bg-blue-planning-100 border-blue-planning-300 bg-blue-planning-300" => @checked}
      )}>
        <input class="hidden" type={@type} name={@name} value={@day} checked={@checked} disabled={@disabled} />
        <%= dyn_gettext String.slice(@day, 0,3) %>
      </label>
    """
  end

  def category_option(assigns) do
    assigns = Enum.into(assigns, %{disabled: false, class: ""})

    ~H"""
      <li class="flex justify-between border hover:border-blue-planning-300 rounded-lg p-6 mb-4">
        <div class="max-w-md">
          <label class="flex">
            <input class="checkbox w-7 h-7" type={@type} name={@name} value={@cost_category.id} checked={@checked} disabled={@disabled} />
            <div class="ml-4">
              <h5 class="text-xl font-bold leading-4"><%= @cost_category.category %></h5>
            </div>
          </label>
        </div>
        <div class="flex flex-col">
          <h6 class="text-2xl font-bold text-center mb-auto"><%= @cost_category.base_cost %></h6>
          <button class="text-center text-blue-planning-300 underline" type="button" phx-click="edit-cost" phx-value-id={@cost_category.id}>Edit costs</button>
        </div>
      </li>
    """
  end

  def financial_review(assigns) do
    ~H"""
      <div class="bg-gray-100 flex justify-between items-center p-8 my-6 rounded-lg" {intro_hints_only("intro_hints_only")}>
        <div>
          <h5 class="text-center font-bold text-4xl mb-2">$45,417</h5>
          <p class="italic text-center">Desired Take Home</p>
        </div>
        <p class="text-center font-bold text-5xl mb-8">+</p>
        <div>
          <h5 class="text-center font-bold text-4xl mb-2">$25,882</h5>
          <p class="italic text-center">Projected Costs</p>
        </div>
        <p class="text-center font-bold text-5xl mb-8">=</p>
        <div>
          <h5 class="text-center font-bold text-4xl mb-2">$70,536</h5>
          <p class="italic text-center">Gross Revenue <.intro_hint content="Your revenue is the total amount of sales you made before any deductions. This includes your costs because you should be including those in your pricing!" class="ml-1" /></p>
        </div>
      </div>
    """
  end

  def sidebar_nav(assigns) do
    ~H"""
    <nav class="bg-gray-100 p-4 mt-8 rounded-lg">
      <ul>
        <li class="flex items-center mb-4 p-3 bg-gray-200 bold rounded-lg font-bold"><span class="bg-blue-planning-300 text-white w-6 h-6 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-sm font-bold">1</span>Information about your business</li>
        <li class="flex items-center mb-4 p-3 bg-gray-200 bold rounded-lg font-bold"><span class="bg-blue-planning-300 text-white w-6 h-6 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-sm font-bold">2</span>Financial & time goals</li>
        <li class="flex items-center mb-4 p-3 bg-gray-200 bold rounded-lg font-bold"><span class="bg-blue-planning-300 text-white w-6 h-6 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-sm font-bold">3</span>Business costs</li>
        <li class="flex items-center p-3 bg-gray-200 bold rounded-lg font-bold"><span class="bg-blue-planning-300 text-white w-6 h-6 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-sm font-bold">4</span>Results</li>
      </ul>
    </nav>
    """
  end

  def container(assigns) do
    ~H"""
      <div class="flex w-screen min-h-screen bg-gray-100 relative">
        <div class="bg-white w-1/4 px-12 py-12 h-screen flex flex-col fixed">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48 mb-10" />
          <h3 class="text-4xl font-bold mb-4">Pricing Calculator</h3>
          <p class="text-2xl mb-4">You probably aren't charging enough and we'd like to help</p>
          <.sidebar_nav step={@step} />
          <div class="circleBtn mt-auto static">
            <ul>
              <li>
                  <a phx-click="exit">
                    <.icon name="back" class="w-14 h-14 stroke-current text-blue-planning-300 rounded-full" />
                    <span class="overflow-hidden">Exit calculator</span>
                  </a>
              </li>
            </ul>
          </div>
        </div>
        <div class="w-3/4 flex flex-col pb-32 ml-auto">
          <div class="max-w-5xl w-full mx-auto mt-40">
            <h1 class="text-4xl font-bold mb-12 flex items-center -ml-14"><%= if @step == 6 do %><button type="button" phx-click="edit-cost-back" class="bg-blue-planning-300 text-white w-12 h-12 inline-block flex items-center justify-center mr-2 rounded-full leading-none"><.icon name="back" class="w-4 h-4 stroke-current" /></button><% else %><span class="bg-blue-planning-300 text-white w-12 h-12 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-xl"><%= @step - 1 %></span><% end %><%= @step_title %></h1>
          </div>
          <div class="max-w-5xl w-full mx-auto bg-blue-planning-300 rounded-lg overflow-hidden">
            <div class="bg-white ml-3 px-6 pt-8 pb-6 sm:p-14">
              <%= render_block(@inner_block) %>
            </div>
          </div>
        </div>
      </div>
    """
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate states(), to: PricingCalculations, as: :state_options
  defdelegate days(), to: PricingCalculations, as: :day_options
  defdelegate cost_categories(), to: PricingCalculations, as: :cost_categories
  defdelegate tax_schedule(), to: PricingCalculations, as: :tax_schedule
end
