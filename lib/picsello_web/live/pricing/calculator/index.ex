defmodule PicselloWeb.Live.Pricing.Calculator.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "calculator"]
  use Picsello.Notifiers

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
          average_time_per_week: 40,
          take_home: Money.new(0),
          self_employment_tax_percentage: tax_schedule().self_employment_percentage,
          desired_salary: Money.new(1_500_000),
          business_costs: cost_categories()
        }
      )
    end)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("start", _params, socket) do
    socket
    |> assign_step(2)
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event("previous", _, %{assigns: %{step: step}} = socket) do
    socket
    |> assign_step(if(step == 6, do: 4, else: step - 1))
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event("exit", _, socket) do
    socket
    |> push_redirect(to: Routes.home_path(socket, :index), replace: true)
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-cost",
        params,
        socket
      ) do
    category_id = Map.get(params, "id", "1")
    category = Map.get(params, "category", "1")

    socket
    |> assign_step(6)
    |> assign_cost_category_step(category_id, category)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"pricing_calculations" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event("step", %{"id" => step}, socket) do
    socket
    |> assign_step(String.to_integer(step))
    |> assign_changeset()
    |> noreply()
  end

  @impl true
  def handle_event("update", %{"pricing_calculations" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, pricing_calculations} ->
        socket
        |> assign(pricing_calculations: pricing_calculations)
        |> assign_step(4)
        |> assign_changeset()
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event(
        "save",
        %{"pricing_calculations" => params},
        %{assigns: %{step: step}} = socket
      ) do
    final_step =
      case step do
        6 -> 4
        5 -> 5
        _ -> step + 1
      end

    case socket |> build_changeset(params) |> Repo.insert_or_update() do
      {:ok, pricing_calculations} ->
        socket
        |> assign(pricing_calculations: pricing_calculations)
        |> assign_step(final_step)
        |> handle_step(step)

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  def handle_event(
        "save",
        _params,
        %{assigns: %{step: step}} = socket
      ) do
    socket
    |> handle_step(step)
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.form let={f} for={@changeset} phx-change={@change} phx-submit="save" id={"calculator-step-#{@step}"}>
        <.step {assigns} f={f} />
      </.form>
    """
  end

  defp step(%{step: 2} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-4xl font-bold">Let us know about what you do</h4>
        <p class="py-2 text-base-250 text-lg">We'll need this in order to generate how much you should charge per shoot.</p>

        <% input_name = input_name(@f, :job_types) <> "[]" %>
        <div class="flex flex-col pb-1">
          <p class="py-2 font-extrabold">
            What types of photography do you offer?
            <i class="italic font-light">(Select one or more)</i>
          </p>

          <div class="mt-2 grid md:grid-cols-3 grid-cols-2 gap-3 sm:gap-5">
            <%= for(job_type <- job_types(), checked <- [Enum.member?(input_value(@f, :job_types) || [], job_type)]) do %>
              <.job_type_option type="checkbox" name={input_name} job_type={job_type} checked={checked} />
            <% end %>
          </div>
        </div>

        <p class="py-2 font-extrabold mt-4">How much time do you spend on your photography business per week? <br /><span class="italic font-normal text-sm text-base-250">(include all marketing, client communications, prep, travel, shoot time, editing, accounting, admin etc)</span></p>
        <label class="flex flex-col">
          <div class="flex items-center">
            <%= input @f, :average_time_per_week, type: :text_input, phx_debounce: 500, min: 0, placeholder: "40", class: "p-4 w-24 text-center" %>
            <span class="ml-4">hours</span>
          </div>
          <%= error_tag @f, :average_time_per_week, class: "text-red-sales-300 text-sm" %>
        </label>

        <div class="flex justify-end mt-8">
          <button type="submit" class="btn-primary" disabled={!@changeset.valid?}>Next</button>
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
        <h4 class="text-4xl font-bold">Let us know how much you’d like to make</h4>
        <p class="py-2 text-base-250 text-lg">Make sure to notice how taxes affect your take home pay. You can easily adjust your Gross Salary needed if the amount of taxes surprises you!</p>

        <div {intro_hints_only("intro_hints_only")}>
          <label class="flex flex-wrap md:flex-nowrap items-center justify-between mt-4 bg-blue-planning-100 p-4 rounded-t-lg gap-12">
            <p class="font-extrabold shrink text-xl">Gross Salary Needed <br /> <span class="italic font-normal text-sm">Remember, this isn't your take home pay. Adjust to make sure your take home is what you need.</span></p>
            <div>
              <%= input @f, :desired_salary, type: :text_input, phx_debounce: 0, min: 0, placeholder: "$60,000", class: "p-4 sm:w-40 w-full sm:mb-0 mb-8 sm:mt-0 mt-4 text-center text-blue-planning-300 font-bold border-blue-planning-300 transition-colors focus:border-white", phx_hook: "PriceMask" %>
              <%= error_tag @f, :desired_salary, class: "text-red-sales-300 text-sm block" %>
            </div>
          </label>
          <hr class="hidden mb-4 sm:block"/>
          <div class="flex flex-wrap items-center justify-between px-4">
            <p class="font-extrabold">Approximate Tax Bracket <br /><span class="italic font-normal text-sm text-base-250">How did you calculate this? <.intro_hint content="Based on the salary you entered, we looked at what the IRS has listed as the percentage band of income you are in." class="ml-1" /></span></p>
            <%= hidden_input(@f, :tax_bracket, value: tax_bracket.percentage ) %>
            <p class="text-base-250 w-full p-4 mt-4 mb-6 text-center bg-gray-100 sm:w-40 sm:bg-transparent sm:mb-0 sm:mt-0 sm:p-0"><%= tax_bracket.percentage %>%</p>
          </div>
          <hr class="hidden mt-4 mb-4 sm:block" />
          <div class="flex flex-wrap items-center justify-between px-4">
            <p class="py-2 font-extrabold">Approximate After Income Tax <br /><span class="italic font-normal text-sm text-base-250"><a class="underline" target="_blank" rel="noopener noreferrer" href="https://support.picsello.com/article/122-how-federal-tax-brackets-work">Learn more</a> about this calculation</span></p>
            <%= hidden_input(@f, :after_income_tax, value: after_tax_income ) %>
            <p class="text-base-250 w-full p-4 mt-4 mb-6 text-center bg-gray-100 sm:w-40 sm:bg-transparent sm:mb-0 sm:mt-0 sm:p-0"><%= after_tax_income %></p>
          </div>
          <hr class="hidden mt-4 mb-4 sm:block" />
          <div class="flex flex-wrap items-center justify-between px-4">
            <p class="py-2 font-extrabold">Self-employment tax <br /><span class="italic font-normal text-sm text-base-250">What's this? <.intro_hint content="Since you are technically self-employed, the IRS has a special tax percentage, this is calculated after your normal income tax. There is no graduation here, just straight 15.3%." class="ml-1" /></span></p>
            <p class="text-base-250 w-full p-4 mt-4 mb-6 text-center bg-gray-100 sm:w-40 sm:bg-transparent sm:mb-0 sm:mt-0 sm:p-0"><%= @pricing_calculations.self_employment_tax_percentage %>%</p>
          </div>
          <hr class="hidden mt-4 mb-4 sm:block" />
          <div class="flex flex-wrap items-center justify-between px-4">
            <p class="py-2 font-extrabold">Approximate After Income Tax & SE Tax <br /><span class="italic font-normal text-sm text-base-250">‘aka your take home pay’</span></p>
            <%= hidden_input(@f, :take_home, value: take_home ) %>
            <p class="text-blue-planning-300 font-bold w-full p-4 mt-4 mb-6 text-center bg-gray-100 sm:w-40 sm:bg-transparent sm:mb-0 sm:mt-0 sm:p-0"><%= take_home %></p>
          </div>
          <hr class="hidden mt-4 mb-4 sm:block" />
        </div>

        <.tax_review tax_amount={PricingCalculations.calculate_tax_amount(desired_salary, take_home)} desired_salary={desired_salary} take_home={take_home} />

        <div class="flex justify-end mt-8">
          <button type="button" class="mr-4 btn-secondary" phx-click="previous">Back</button>
          <button type="submit" class="btn-primary" disabled={!@changeset.valid?}>Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 4} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-4xl font-bold">Let’s see how much you spend on your business</h4>
        <p class="py-2 text-base-250 text-lg">We've provided an estimate on what your costs should be based on industry standards. You can go in and tweak based on your actuals.</p>

        <h4 class="my-4 text-xl font-bold text-base-250">Cost categories</h4>
        <ul>
          <%= inputs_for @f, :business_costs, fn fp -> %>
            <.category_option type="checkbox" form={fp} />
          <% end %>
        </ul>

        <.financial_review desired_salary={@pricing_calculations.desired_salary} costs={PricingCalculations.calculate_all_costs(@pricing_calculations.business_costs)} />

        <div class="flex justify-end mt-8">
          <button type="button" class="mr-4 btn-secondary" phx-click="previous">Back</button>
          <button type="submit" class="btn-primary" disabled={!@changeset.valid?}>Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 5} = assigns) do
    costs = PricingCalculations.calculate_all_costs(assigns.pricing_calculations.business_costs)

    gross_revenue =
      PricingCalculations.calculate_revenue(
        assigns.pricing_calculations.take_home,
        costs
      )

    desired_salary = input_value(assigns.f, :desired_salary)
    average_time_per_week = input_value(assigns.f, :average_time_per_week)

    calculations = %{
      job_types: assigns.pricing_calculations.job_types,
      average_time_per_week:
        if average_time_per_week === 0 do
          1
        else
          average_time_per_week
        end,
      desired_salary: desired_salary
    }

    assigns =
      Enum.into(assigns, %{
        costs: costs,
        gross_revenue: gross_revenue
      })

    ~H"""
      <.container {assigns}>
        <h4 class="text-4xl font-bold">Here's your results!</h4>
        <p class="py-2 text-base-250 text-lg">Based on what you told us—we’ve calculated some suggestions on how much to charge and how many shoots you should do. The suggested pricing and shoot counts are calculated for the entire year if you focused on one. You can go ahead and adjust your work week length and salary if you'd like.</p>

        <h4 class="mt-4 mb-4 text-xl font-bold text-base-250">Adjust calculation</h4>
        <div class="grid sm:grid-cols-2 gap-8 p-4 border rounded-lg">
          <label class="flex gap-4 items-center">
            <p class="pb-2 font-bold shrink-0">Gross Salary Needed:</p>
            <div class="flex flex-col items-center">
              <%= input @f, :desired_salary, type: :text_input, phx_debounce: 0, min: 0, placeholder: "$60,000", class: "p-4 sm:w-40 w-full sm:mb-0 mb-8 sm:mt-0 mt-4 text-center", phx_hook: "PriceMask" %>
              <%= error_tag @f, :desired_salary, class: "text-red-sales-300 text-sm block" %>
            </div>
          </label>
          <label class="flex gap-4 items-center">
            <p class="pb-2 font-bold shrink-0">My average time each week is:</p>
            <div class="flex flex-wrap items-center">
              <%= input @f, :average_time_per_week, type: :text_input, phx_debounce: 500, min: 0, placeholder: "40", class: "p-4 w-24 text-center" %>
              <span class="ml-4">hours</span>
              <%= error_tag @f, :average_time_per_week, class: "text-red-sales-300 text-sm block" %>
            </div>
          </label>
        </div>

        <div class="my-6">
          <h4 class="mt-4 text-xl font-bold text-base-250">Shoot breakdown based on desired salary</h4>
          <p class="mb-4 text-base-250">If you only focused on 100% of that shoot type per year</p>
          <%= for {pricing_suggestion, index} <- Enum.with_index(PricingCalculations.calculate_pricing_by_job_types(calculations)) do %>
            <.pricing_suggestion job_type={pricing_suggestion.job_type} gross_revenue={@gross_revenue} pricing_calculations={@pricing_calculations} max_session_per_year={pricing_suggestion.max_session_per_year} base_price={pricing_suggestion.base_price} actual_salary={pricing_suggestion.actual_salary} index={index} />
          <% end %>
        </div>

        <.financial_review desired_salary={desired_salary} costs={@costs} />

        <div class="flex justify-end mt-8">
          <button type="button" class="mr-4 btn-secondary" phx-click="previous">Back</button>
          <button type="submit" class="btn-primary">Email results</button>
        </div>
      </.container>

      <%= if @show_modal do %>
      <div class="fixed inset-0 flex items-center justify-center bg-black/60">
        <div class="rounded-lg dialog">
          <.icon name="confetti" class="w-11 h-11" />

          <h1 class="text-3xl font-semibold">Your results have been saved and emailed to you!</h1>
          <p class="pt-4">Thanks! You can come back to this calculator at any time and modify your results.</p>

          <button class="w-full mt-6 btn-primary" type="button" phx-click="exit">
            Go to my dashboard
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  defp step(%{step: 6} = assigns) do
    ~H"""
      <.container {assigns}>
        <div class="items-center hidden w-full border-b-8 lg:grid lg:grid-cols-3 gap-2 border-blue-planning-300 ">
          <div class="pb-4 font-bold col-start-1">Item</div>
          <div class="pb-4 font-bold text-center col-start-2">Your Cost Monthy</div>
          <div class="pb-4 font-bold text-center col-start-3">Your Cost Yearly</div>
        </div>
        <%= inputs_for @f, :business_costs, fn fp -> %>
          <.cost_item form={fp} category_id={@category_id} changeset={@changeset} />
        <% end %>
        <div class="flex justify-end mt-8">
          <button type="submit" class="mr-4 btn-primary" disabled={!@changeset.valid?}>Save & go back</button>
        </div>
      </.container>
    """
  end

  defp step(assigns) do
    ~H"""
    <div class="relative flex flex-col items-center w-screen min-h-screen p-5 bg-gray-100 sm:justify-center">
      <div class="absolute circleBtn bottom-12 left-12">
        <ul>
          <li>
            <a phx-click="exit" href="#">
              <.icon name="back" class="rounded-full stroke-current w-14 h-14 text-blue-planning-300" />
              <span class="overflow-hidden">Exit calculator</span>
            </a>
          </li>
        </ul>
      </div>
      <.icon name="logo" class="w-32 mb-10 h-7 sm:h-11 sm:w-48" />
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <h1 class="mb-10 text-4xl font-bold md:text-6xl text-center">Smart Profit <span class="border-b-4 md:border-b-8 border-blue-planning-300">Calculator</span></h1>
        <p class="mb-4 text-xl text-base-250">Easy-to-use and backed by 3 years of industry research, our calculator helps you set your prices so your business can be profitable. We have 4 quick sections for you to fill out so let’s go!</p>
        <ul class="flex flex-wrap columns-2">
          <li class="flex items-center w-full mb-2 md:w-1/2 text-base-250 font-bold"><span class="flex items-center justify-center block w-8 h-8 mr-2 font-bold text-white rounded-full bg-blue-planning-300"><span class="-mt-1">1</span></span>Business information</li>
          <li class="flex items-center w-full mb-2 md:w-1/2 text-base-250 font-bold"><span class="flex items-center justify-center block w-8 h-8 mr-2 font-bold text-white rounded-full bg-blue-planning-300"><span class="-mt-1">2</span></span>Financial goals</li>
          <li class="flex items-center w-full mb-2 md:w-1/2 text-base-250 font-bold"><span class="flex items-center justify-center block w-8 h-8 mr-2 font-bold text-white rounded-full bg-blue-planning-300"><span class="-mt-1">3</span></span>Business costs</li>
          <li class="flex items-center w-full mb-2 md:w-1/2 text-base-250 font-bold"><span class="flex items-center justify-center block w-8 h-8 mr-2 font-bold text-white rounded-full bg-blue-planning-300"><span class="-mt-1">4</span></span>Results</li>
        </ul>
        <div class="flex justify-end mt-8">
            <%= live_redirect "Go back", to: Routes.home_path(@socket, :index), class: "btn-secondary inline-block mr-4" %>
          <button type="button" class="btn-primary" phx-click="start">Get started</button>
        </div>
      </div>
    </div>
    """
  end

  defp assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      step_title: "Business information",
      page_title: "Smart Profit Calculator—Step 1",
      change: "validate"
    )
  end

  defp assign_step(socket, 3) do
    socket
    |> assign(
      step: 3,
      step_title: "Financial goals",
      page_title: "Smart Profit Calculator—Step 2",
      change: "validate"
    )
  end

  defp assign_step(socket, 4) do
    socket
    |> assign(
      step: 4,
      step_title: "Business costs",
      page_title: "Smart Profit Calculator—Step 3",
      change: "update"
    )
  end

  defp assign_step(socket, 5) do
    socket
    |> assign(
      step: 5,
      step_title: "Results",
      page_title: "Smart Profit Calculator—Step 4",
      change: "validate",
      show_modal: false
    )
  end

  defp assign_step(socket, 6) do
    socket
    |> assign(
      step: 6,
      step_title: "Edit business cost",
      page_title: "Edit business cost",
      change: "validate"
    )
  end

  defp assign_step(socket, _) do
    socket
    |> assign(
      step: 1,
      step_title: "Tell us more about yourself",
      page_title: "Smart Profit Calculator",
      change: "validate"
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

  defp assign_cost_category_step(socket, category_id, category) do
    socket
    |> assign(
      step: 6,
      category_id: category_id,
      step_title: "Edit #{category} costs",
      page_title: "Edit #{category} costs",
      change: "validate"
    )
  end

  def day_option(assigns) do
    assigns = Enum.into(assigns, %{disabled: false, class: ""})

    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:bg-blue-planning-100/60 cursor-pointer font-semibold text-sm leading-tight sm:text-base w-12 flex items-center justify-center mr-4 capitalize mb-4 #{@class}",
        %{"bg-blue-planning-100 border-blue-planning-300 bg-blue-planning-300" => @checked}
      )}>
        <input class="hidden" type={@type} name={@name} value={@day} checked={@checked} disabled={@disabled} />
        <%= dyn_gettext String.slice(@day, 0,3) %>
      </label>
    """
  end

  def category_option(assigns) do
    ~H"""
      <li class="flex justify-between p-6 mb-4 border rounded-lg hover:border-blue-planning-300">
        <div class="max-w-md">
          <label class="flex">
            <%= hidden_input @form, :id %>
            <%= hidden_input @form, :category %>
            <%= hidden_input @form, :description %>
            <%= input @form, :active, type: :checkbox, class: "checkbox w-7 h-7" %>
            <div class="ml-4">
              <h5 class="text-xl font-bold leading-4"><%= input_value(@form, :category) %></h5>
              <p class="mt-1"><%= input_value(@form, :description) %></p>
            </div>
          </label>
        </div>
        <div class="flex flex-col">
          <h6 class="mb-auto text-2xl font-bold text-center"><%= PricingCalculations.calculate_costs_by_category(@form.data.line_items) %></h6>
          <button class="text-center underline text-blue-planning-300" type="button" phx-click="edit-cost" phx-value-id={input_value(@form, :id)} phx-value-category={input_value(@form, :category)}>Edit costs</button>
        </div>
      </li>
    """
  end

  def cost_item(assigns) do
    ~H"""
      <%= inputs_for @form, :line_items, fn li -> %>
        <%= hidden_input @form, :category %>
        <%= hidden_input @form, :description %>
        <%= hidden_input @form, :active %>
        <%= if input_value(@form, :id) == @category_id do %>
          <div class="items-center w-full lg:grid grid-cols-3 gap-2 even:bg-gray-100">
            <div class="w-full p-4 text-center col-start-1 lg:w-auto lg:text-left">
              <strong><%= input_value(li, :title) %></strong> <br />
              <%= input_value(li, :description) %>
            </div>
            <div class="w-full p-4 text-center col-start-2 lg:w-auto">
              <%= input_value(li, :yearly_cost) |> PricingCalculations.calculate_monthly() %><span class="border-b-2 border-dotted cursor-pointer text-blue-planning-300 border-blue-planning-300" phx-hook="DefaultCostTooltip" id={"default-cost-tooltip-monthly-#{li.id}"} >/month <span class="hidden p-1 text-sm text-left text-black bg-white rounded shadow" role="tooltip"><strong class="opacity-40">Suggested:</strong><br /><%= input_value(li, :yearly_cost_base) |> PricingCalculations.calculate_monthly() %> /month</span></span>
            </div>
            <div class="flex items-center w-full p-4 text-center col-start-3 lg:w-auto">
              <%= hidden_input li, :yearly_cost_base %>
              <%= input li, :yearly_cost, type: :text_input, phx_debounce: 0, min: 0, placeholder: "$200", class: "p-4 lg:w-40 w-full text-center", phx_hook: "PriceMask" %><span class="ml-2 border-b-2 border-dotted cursor-pointer text-blue-planning-300 border-blue-planning-300" phx-hook="DefaultCostTooltip" id={"default-cost-tooltip-yearly-#{li.id}"}>/year <span class="hidden p-1 text-sm text-left text-black bg-white rounded shadow" role="tooltip"><strong class="opacity-40">Suggested:</strong><br /><%= input_value(li, :yearly_cost_base) %> /year</span></span>
            </div>
          </div>
        <% else %>
          <%= hidden_input li, :title %>
          <%= hidden_input li, :description %>
          <%= hidden_input li, :yearly_cost %>
          <%= hidden_input li, :yearly_cost_base %>
      <% end %>
    <% end %>
    <%= if input_value(@form, :id) == @category_id do %>
    <div class="items-center w-full lg:grid lg:grid-cols-3 gap-2">
      <div class="p-4 text-center col-start-1 lg:text-left">
        <p class="text-lg font-bold"><%= input_value(@form, :category) %> Totals</p>
      </div>
      <div class="p-4 col-start-2">
      <p class="font-bold text-center"><%= PricingCalculations.calculate_costs_by_category(assigns.form.data.line_items, assigns.form.params) |> PricingCalculations.calculate_monthly() %>/month</p>
      </div>
      <div class="p-4 col-start-3">
        <p class="font-bold text-center"><%= PricingCalculations.calculate_costs_by_category(assigns.form.data.line_items, assigns.form.params) %>/year</p>
      </div>
    </div>
    <% end %>
    """
  end

  def financial_review(assigns) do
    ~H"""
      <h4 class="mt-4 mb-6 text-xl font-bold text-base-250">Financial summary</h4>
      <div class="flex flex-wrap items-center justify-between p-8 mt-2 mb-6 bg-gray-100 rounded-lg" {intro_hints_only("intro_hints_only")}>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= @desired_salary %></h5>
          <p class="italic text-center">Gross Salary (Before Taxes)</p>
        </div>
        <p class="w-full text-5xl font-bold text-center text-base-250 sm:mb-8 sm:w-auto">+</p>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= @costs %></h5>
          <p class="italic text-center">Projected Costs</p>
        </div>
        <p class="w-full text-5xl font-bold text-center text-base-250 sm:mb-8 sm:w-auto">=</p>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= PricingCalculations.calculate_revenue(@desired_salary, @costs) %></h5>
          <p class="italic text-center">Gross Revenue <.intro_hint content="Your revenue is the total amount of sales you made before any deductions. This includes your costs because you should be including those in your pricing!" class="ml-1" /></p>
        </div>
      </div>
    """
  end

  def tax_review(assigns) do
    ~H"""
      <h4 class="mt-8 mb-6 text-xl font-bold text-base-250">Tax summary</h4>
      <div class="flex flex-wrap items-center justify-between p-8 mt-2 mb-6 bg-gray-100 rounded-lg" {intro_hints_only("intro_hints_only")}>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= @desired_salary %></h5>
          <p class="italic text-center">Gross Salary (before taxes)</p>
        </div>
        <p class="w-full text-5xl font-bold text-center text-base-250 sm:mb-8 sm:w-auto">-</p>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= @tax_amount %></h5>
          <p class="italic text-center">Approx. income tax + SE tax</p>
        </div>
        <p class="w-full text-5xl font-bold text-center text-base-250 sm:mb-8 sm:w-auto">=</p>
        <div class="w-full sm:w-auto">
          <h5 class="mb-2 text-4xl font-bold text-center"><%= @take_home %></h5>
          <p class="italic text-center">Total Take Home Pay <.intro_hint content="This doesn't include your expenses or any savings from business cost deductions" class="ml-1" /></p>
        </div>
      </div>
    """
  end

  def pricing_suggestion(assigns) do
    ~H"""
      <div class="p-4 mb-4 border rounded-lg">
        <div class="flex items-center">
          <div class="flex items-center justify-center flex-shrink-0 w-12 h-12 ml-1 mr-3 bg-gray-100 rounded-full">
            <.icon name={@job_type} class="fill-current" width="24" height="24" />
          </div>
          <div>
            <h3 class="text-lg font-bold"><%= dyn_gettext @job_type %></h3>
            <p class="text-xs text-base-250">Results reflect if you only focused on <%= dyn_gettext @job_type %> shoots this year</p>
            <input id={"calculator-step-5_pricing_suggestions_#{@index}_job_type"} name={"pricing_calculations[pricing_suggestions][#{@index}][job_type]"} type="hidden" value={@job_type}>
            <input id={"calculator-step-5_pricing_suggestions_#{@index}_max_session_per_year"} name={"pricing_calculations[pricing_suggestions][#{@index}][max_session_per_year]"} type="hidden" value={@max_session_per_year}>
            <input id={"calculator-step-5_pricing_suggestions_#{@index}_base_price"} name={"pricing_calculations[pricing_suggestions][#{@index}][base_price]"} type="hidden" value={@base_price}>
          </div>
        </div>
        <div class="flex flex-wrap items-center justify-between gap-4 mt-4">
          <div class="flex flex-col flex-wrap items-center justify-center p-4 bg-gray-100 rounded-lg w-full sm:w-auto sm:grow">
            <span class="block w-full text-2xl font-bold text-center">
            <%= @max_session_per_year %>
            </span>
            <span class="block w-full text-center italic">
              Total Shoots per year
            </span>
          </div>
          <p class="w-full text-4xl font-bold text-base-250 text-center sm:mb-6 sm:w-auto">x</p>
          <div class="flex flex-col flex-wrap items-center justify-center p-4 text-white bg-blue-planning-300 rounded-lg w-full sm:w-auto sm:grow">
            <span class="block w-full text-2xl font-bold text-center">
              <%= @base_price %>
            </span>
            <span class="block w-full text-center italic">
              Charge Per Shoot
            </span>
          </div>
          <p class="w-full text-5xl font-bold text-base-250 text-center sm:mb-6 sm:w-auto">=</p>
          <div class="flex flex-col flex-wrap items-center justify-center p-4 text-white bg-blue-planning-300 rounded-lg w-full sm:w-auto sm:grow">
            <span class="block w-full text-2xl font-bold text-center">
              <%= @actual_salary %>
            </span>
            <span class="block w-full text-center italic">
              Desired Salary
            </span>
          </div>
        </div>
      </div>
    """
  end

  def sidebar_nav(assigns) do
    ~H"""
    <nav class="hidden px-4 pt-4 mt-4 bg-gray-100 rounded-lg lg:block">
      <ul>
        <.sidebar_step current_step={@step} step={1} title="Business information" />
        <.sidebar_step current_step={@step} step={2} title="Financial goals" />
        <.sidebar_step current_step={@step} step={3} title="Business costs" />
        <.sidebar_step current_step={@step} step={4} title="Results" />
      </ul>
    </nav>
    """
  end

  def sidebar_step(%{step: step, current_step: current_step} = assigns) do
    next_step = step + 1
    current_step = if(current_step == 6, do: 4, else: current_step)

    assigns =
      Enum.into(assigns, %{
        next_step: next_step,
        active: current_step >= next_step,
        done: current_step > next_step
      })

    ~H"""
      <li {output_step_nav(@done, @next_step)} class={classes("flex items-center mb-4 p-3 bg-gray-200 bold rounded-lg font-bold text-blue-planning-300 cursor-pointer", %{"text-gray-500 opacity-70 cursor-default" => !@active})}
      )}>
        <span class={classes("bg-blue-planning-300 text-white w-6 h-6 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-sm font-bold",
        %{"bg-gray-300 text-gray-500 opacity-70" => !@active})}>
          <%= if @done do %>
            <.icon name="checkmark" class="p-2 stroke-current text-base-100" />
          <% else %>
            <span class="-mt-1"><%= @step %></span>
          <% end %>
        </span>
        <%= @title %>
        </li>
    """
  end

  def container(assigns) do
    ~H"""
      <div class="relative flex w-screen min-h-screen bg-gray-100">
        <div class="fixed flex flex-col w-full px-8 py-8 bg-white lg:w-1/4 lg:px-12 lg:py-12 lg:h-screen">
          <div class="flex justify-between lg:block">
            <.icon name="logo" class="w-32 ml-16 lg:ml-0 h-7 lg:h-11 lg:w-48 lg:mb-4" />
            <h3 class="text-xl font-bold lg:text-4xl lg:mb-4">Smart Profit Calculator </h3>
          </div>
          <p class="hidden text-xl text-base-250 lg:block">Let’s figure out your prices so your business can be a profitable one!</p>
          <.sidebar_nav step={@step} />
          <div class="absolute bottom-auto circleBtn lg:bottom-8 lg:left-8 lg:top-auto top-5 left-5">
            <ul>
              <li>
                  <a phx-click="exit">
                    <.icon name="back" class="rounded-full stroke-current w-14 h-14 text-blue-planning-300" />
                    <span class="overflow-hidden">Exit calculator</span>
                  </a>
              </li>
            </ul>
          </div>
        </div>
        <div class="flex flex-col w-full px-4 pb-12 ml-auto lg:w-3/4 sm:pb-32 sm:px-16">
          <div class="w-full max-w-5xl mx-auto mt-32 sm:mt-40">
            <h1 class="flex items-center mb-8 text-xl font-bold sm:text-2xl text-base-250">
              <%= if @step == 6 do %>
                <div phx-click="previous" class="flex items-center justify-center inline-block w-8 h-8 mr-2 leading-none text-white rounded-full cursor-pointer bg-blue-planning-300">
                  <.icon name="back" class="w-4 h-4 stroke-current" />
                </div>
              <% else %>
                <span class="flex items-center justify-center inline-block w-8 h-8 mr-2 text-xl leading-none text-white rounded-full bg-blue-planning-300">
                  <span class="-mt-1"><%= @step - 1 %></span>
                </span>
              <% end %>
              <%= @step_title %>
            </h1>
          </div>
          <div class="w-full max-w-5xl mx-auto overflow-hidden rounded-lg bg-blue-planning-300">
            <div class="px-6 pt-8 pb-6 ml-3 bg-white sm:p-14">
              <%= render_block(@inner_block) %>
            </div>
          </div>
        </div>
      </div>
    """
  end

  defp handle_step(
         %{
           assigns: %{
             current_user: %{email: email, name: name},
             pricing_calculations: %{
               business_costs: business_costs,
               take_home: take_home,
               pricing_suggestions: pricing_suggestions
             }
           }
         } = socket,
         step
       ) do
    case step do
      5 ->
        opts = [
          take_home: take_home |> Money.to_string(),
          projected_costs:
            PricingCalculations.calculate_all_costs(business_costs)
            |> Money.to_string(),
          gross_revenue:
            PricingCalculations.calculate_revenue(
              take_home,
              PricingCalculations.calculate_all_costs(business_costs)
            )
            |> Money.to_string(),
          pricing_suggestions: pricing_suggestions |> Enum.map(&pricing_suggestions_for_email(&1))
        ]

        sendgrid_template(:calculator_template, opts)
        |> to({name, email})
        |> from({"Picsello", "noreply@picsello.com"})
        |> deliver_later()

        socket
        |> assign(show_modal: true)
        |> assign_changeset()
        |> noreply()

      _ ->
        socket
        |> assign_changeset()
        |> noreply()
    end
  end

  defp pricing_suggestions_for_email(%{
         base_price: base_price,
         job_type: job_type,
         max_session_per_year: max_session_per_year
       }) do
    %{
      base_price: base_price |> Money.to_string(),
      job_type: dyn_gettext(job_type),
      max_session_per_year: max_session_per_year
    }
  end

  defp output_step_nav(done, step) do
    case done do
      true -> %{phx_click: "step", phx_value_id: step}
      _ -> %{}
    end
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate days(), to: PricingCalculations, as: :day_options
  defdelegate cost_categories(), to: PricingCalculations, as: :cost_categories
  defdelegate tax_schedule(), to: PricingCalculations, as: :tax_schedule
end
