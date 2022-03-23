defmodule PicselloWeb.Live.Pricing.Calculator.Index do
  use PicselloWeb, live_view: [layout: "calculator"]

  alias Picsello.PricingCalculators
  alias Picsello.{Repo, JobType, Onboardings}

  @impl true
  def mount(_params, _session, socket) do
    socket |> ok()
  end

  @impl true
  def handle_params(params, _session, socket) do
    step = Map.get(params, "step", "1") |> String.to_integer()

    if step == 6 do
      socket
      |> assign_step(6)
      |> assign_cost_category(%{"title" => "hey"})
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
    socket
    |> assign_step(6)
    |> assign_cost_category(params)
    |> assign_changeset()
    |> push_patch(to: Routes.calculator_path(socket, :index, %{step: 6}))
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

        <%= for o <- inputs_for(@f, :organization) do %>
          <%= hidden_inputs_for o %>

          <%= for p <- inputs_for(o, :profile) do %>
            <% input_name = input_name(p, :job_types) <> "[]" %>
            <div class="flex flex-col pb-1">
              <p class="py-2 font-extrabold">
                What’s your speciality?
                <i class="italic font-light">(Select one or more)</i>
              </p>

              <div class="mt-2 grid grid-cols-3 gap-3 sm:gap-5">
                <%= for(job_type <- job_types(), checked <- [Enum.member?(input_value(p, :job_types) || [], job_type)]) do %>
                  <.job_type_option type="checkbox" name={input_name} job_type={job_type} checked={checked} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>

        <%= for onboarding <- inputs_for(@f, :onboarding) do %>
          <div class="grid grid-cols-2 gap-3 sm:gap-5">
            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">Are you a full-time or part-time photographer?</p>

              <%= select onboarding, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select p-4" %>
            </label>

            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">How many years have you been a photographer?</p>

              <%= input onboarding, :photographer_years, type: :number_input, phx_debounce: 500, min: 0, placeholder: "22", class: "p-4" %>
              <%= error_tag onboarding, :photographer_years, class: "text-red-sales-300 text-sm" %>
            </label>
          </div>

          <div class="grid grid-cols-2 gap-3 sm:gap-5">
            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">What's your zipcode?</p>

              <%= input onboarding, :zipcode, type: :text_input, phx_debounce: 500, min: 0, placeholder: "12345", class: "p-4" %>
              <%= error_tag onboarding, :zipcode, class: "text-red-sales-300 text-sm" %>
            </label>

            <label class="flex flex-col mt-4">
              <p class="py-2 font-extrabold">Where’s your business based?</p>

              <%= select onboarding, :state, [{"select one", nil}] ++ @states, class: "select p-4" %>
              <%= error_tag onboarding, :state, class: "text-red-sales-300 text-sm" %>
            </label>
          </div>
        <% end %>

        <div class="flex justify-end mt-8">
          <button type="button" class="btn-primary" phx-click="next">Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 3} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">Let us know how much time you spend and how much you’d like to make.</h4>
        <form>
          <p class="py-2 font-extrabold">What does your average weekly dedication look like for your photography business? (include all marketing, client communications, shoots, editing, travel, weekends, prep, etc)</p>
          <div>
            <div>
              <label class="flex flex-col mt-4">
                <p class="py-2">My average time each week is:</p>
                input placeholder
              </label>
            </div>
            <div>
              <label class="flex flex-col mt-4">
                <p class="py-2">I frequently work the following days:</p>
                input placeholder
              </label>
            </div>
          </div>
          <div>
            <p class="py-2 font-extrabold">How much do you want to take home a year after taxes? (including healthcare costs)</p>
            <label class="flex flex-col mt-4">
              <p class="font-extrabold py-2">Annual Desired Salary</p>
                input placeholder
            </label>
            <label class="flex flex-col mt-4">
              <p class="font-extrabold py-2">Approximate Tax Bracket</p>
                input placeholder
            </label>
            <div class="flex flex-col mt-4">
              <p class="font-extrabold py-2">Approximate After Income Tax</p>
                number calculation
            </div>
            <label class="flex flex-col mt-4">
              <p class="font-extrabold py-2">Self-employment tax</p>
                input placeholder
            </label>
            <div class="flex flex-col mt-4">
              <p class="font-extrabold py-2">Approximate After Income Tax</p>
                number calculation
            </div>
          </div>
        </form>
        <div class="flex justify-end mt-8">
          <button type="button" class="btn-secondary mr-4" phx-click="previous">Back</button>
          <button type="button" class="btn-primary" phx-click="next">Next</button>
        </div>
      </.container>
    """
  end

  defp step(%{step: 4} = assigns) do
    ~H"""
      <.container {assigns}>
        <h4 class="text-2xl font-bold">All businesses have costs. Lorem ipsum dolor sit amet content here.</h4>
        <p>(We’ll provide you a rough estimate on what these should cost you by what you’ve answered so far. You can go in tweak what you need.)</p>
        <div>
          <div>
            <h5>number</h5>
            <p>Desired Take Home</p>
          </div>
          <p>+</p>
          <div>
            <h5>number</h5>
             <p>Projected Costs</p>
          </div>
          <p>=</p>
          <div>
            <h5>number</h5>
            <p>Gross Revenue</p>
          </div>
        </div>
        <form>
          <ul>
            <li>
              <div>
                <h5>Equipment</h5>
                <p>Lorem ipsum really short description goes here about the costs  listed here</p>
              </div>
              <div>
                <h6>number</h6>
                <button type="button" phx-click="edit-cost" phx-value-title="Equipment Costs">Edit costs</button>
              </div>
            </li>
          </ul>
        </form>
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
        edit business cost
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

  defp build_changeset(%{assigns: %{current_user: user, step: step}}, params, action \\ nil) do
    user
    |> PricingCalculators.changeset(params, step: step)
    |> Map.put(:action, action)
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  defp assign_cost_category(socket, %{"title" => title} = params) do
    socket
    |> assign(
      step_title: title,
      page_title: title
    )
    |> IO.inspect()
  end

  def container(assigns) do
    ~H"""
      <div class="flex w-screen min-h-screen bg-gray-100 relative">
        <div class="bg-white w-1/4 px-12 py-12 min-h-screen flex flex-col">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48 mb-10" />
          <h3 class="text-4xl font-bold mb-4">Pricing Calculator</h3>
          <p class="text-2xl mb-4">You probably aren't charging enough and we'd like to help</p>
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
        <div class="w-3/4 flex flex-col">
          <div class="max-w-5xl w-full mx-auto mt-40">
            <h1 class="text-4xl font-bold mb-12 flex items-center -ml-14"><%= if @step == 6 do %><button type="button" phx-click="edit-cost-back" class="bg-blue-planning-300 text-white w-12 h-12 inline-block flex items-center justify-center mr-2 rounded-full leading-none">back</button><% else %><span class="bg-blue-planning-300 text-white w-12 h-12 inline-block flex items-center justify-center mr-2 rounded-full leading-none text-xl"><%= @step - 1 %></span><% end %><%= @step_title %></h1>
          </div>
          <div class="max-w-5xl w-full mx-auto px-6 pt-8 pb-6 bg-white rounded-lg sm:p-14">
            <%= render_block(@inner_block) %>
          </div>
        </div>
      </div>
    """
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate states(), to: PricingCalculators, as: :state_options
end
