defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]

  import PicselloWeb.GalleryLive.Shared, only: [steps: 1]

  import PicselloWeb.OnboardingLive.Shared,
    only: [
      form_field: 1,
      save_final: 2,
      save_multi: 3,
      assign_changeset: 1,
      assign_changeset: 2,
      org_job_inputs: 1
    ]

  require Logger

  alias Picsello.{Onboardings, Onboardings.Onboarding, Subscriptions}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_step()
    |> assign(:stripe_loading, false)
    |> assign(
      :subscription_plan_metadata,
      Subscriptions.get_subscription_plan_metadata()
    )
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: 2}} = socket), do: socket |> noreply()

  @impl true
  def handle_event("previous", %{}, %{assigns: %{step: step}} = socket) do
    socket |> assign_step(step - 1) |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket |> assign_changeset() |> noreply()
  end

  @impl true
  def handle_event("save", %{"user" => params}, %{assigns: %{step: 3}} = socket) do
    save_final(socket, params)
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    save(socket, params)
  end

  @impl true
  def handle_event("go-dashboard", %{}, socket) do
    socket
    |> push_redirect(to: Routes.home_path(socket, :index), replace: true)
    |> noreply()
  end

  @impl true
  def handle_event("trial-code", %{"code" => code}, socket) do
    supscription_plan_metadata = Subscriptions.get_subscription_plan_metadata(code)

    step_title =
      if socket.assigns.step === 4 do
        supscription_plan_metadata.onboarding_title
      else
        socket.assigns.step_title
      end

    socket
    |> assign(
      :subscription_plan_metadata,
      supscription_plan_metadata
    )
    |> assign(step_title: step_title)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.container step={@step} color_class={@color_class} title={@step_title} subtitle={@subtitle}>
        <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"onboarding-step-#{@step}"}>
          <.step f={f} {assigns} />

          <div class="flex items-center justify-between mt-5 sm:justify-end sm:mt-9" phx-hook="HandleTrialCode" id="handle-trial-code" data-handle="retrieve">
            <%= if @step > 2 do %>
              <button type="button" phx-click="previous" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
                Back
              </button>
            <% else %>
              <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete, class: "flex-grow sm:flex-grow-0 underline mr-auto text-left") %>
            <% end %>
            <button type="submit" phx-disable-with="Saving" disabled={!@changeset.valid? || @stripe_loading} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">
              <%= if @step == 3, do: "Start Trial", else: "Next" %>
            </button>
          </div>
        </.form>
      </.container>
    """
  end

  defp step(%{step: 2} = assigns) do
    assigns = assign(assigns, input_class: "p-4")

    ~H"""
      <%= for org <- inputs_for(@f, :organization) do %>
        <%= hidden_inputs_for org %>

        <.form_field label="What’s the name of your photography business?" error={:name} prefix="Photography business name" f={org} mt={0} >
          <%= input org, :name, phx_debounce: "500", placeholder: "Jack Nimble Photography", class: @input_class %>
          <p class="italic text-sm text-gray-400 mt-2">We generate a URL for your Public Profile based on your business name. Here’s a preview: <%= PicselloWeb.Router.Helpers.profile_url(PicselloWeb.Endpoint, :index, input_value(org, :slug)) %></p>
        </.form_field>

      <% end %>
      <hr class="mt-6 border-base-200" />

      <%= for onboarding <- inputs_for(@f, :onboarding) do %>

        <div class="grid sm:grid-cols-2 gap-4">
          <.form_field label="Are you a full-time or part-time photographer?" error={:schedule} f={onboarding} >
            <%= select onboarding, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select #{@input_class}" %>
          </.form_field>

          <.form_field label="How many years have you been a photographer?" error={:photographer_years} f={onboarding} >
            <%= input onboarding, :photographer_years, type: :number_input, phx_debounce: 500, min: 0, placeholder: "e.g. 0, 1, 2, etc.", class: @input_class %>
          </.form_field>
        </div>

        <%= hidden_input onboarding, :welcome_count, value: 0 %>

        <.form_field label="Where’s your business based?" error={:state} f={onboarding} >
          <%= select onboarding, :state, [{"select one", nil}] ++ @states, class: "select #{@input_class}" %>
        </.form_field>

        <div class="grid sm:grid-cols-2 gap-4">
          <.form_field label="Share your Instagram handle" class="py-1.5" >
            <em class="pb-3 text-base-250 text-xs">(optional)</em>
            <%= input onboarding, :social_handle, phx_debounce: 500, min: 0, placeholder: "Let’s meet on the Gram", class: @input_class %>
          </.form_field>

          <.form_field label="How did you first hear about us?" class="py-1.5" >
            <em class="pb-3 text-base-250 text-xs">(optional)</em>
            <%= select onboarding, :online_source, [{"select one", nil} | Onboarding.online_source_options()], class: "select #{@input_class}" %>
          </.form_field>
        </div>
      <% end %>
    """
  end

  defp step(%{step: 3} = assigns) do
    ~H"""
      <.org_job_inputs {assigns} />
    """
  end

  defp assign_step(%{assigns: %{current_user: %{onboarding: onboarding}}} = socket) do
    if is_nil(onboarding.state) && is_nil(onboarding.photographer_years) &&
         is_nil(onboarding.schedule),
       do: assign_step(socket, 2),
       else: assign_step(socket, 3)
  end

  defp assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      color_class: "bg-orange-inbox-200",
      step_title: "Tell us more about yourself",
      subtitle: "",
      page_title: "Onboarding Step 2"
    )
    |> assign_new(:states, &states/0)
  end

  defp assign_step(socket, 3) do
    socket
    |> assign(
      step: 3,
      color_class: "bg-blue-gallery-200",
      step_title: "Customize your business",
      subtitle: "",
      page_title: "Onboarding Step 3"
    )
  end

  def optimized_container(assigns) do
    ~H"""
      <div class="flex items-stretch w-screen min-h-screen flex-wrap">
        <div class="lg:w-1/3 w-full flex flex-col justify-center px-8 lg:px-16 py-8">
          <div class="flex justify-between items-center">
            <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
            <div class="mb-5">
              <.steps step={@step} steps={@steps} for={:sign_up} />
            </div>
          </div>
          <%= render_slot(@inner_block) %>
        </div>
        <div class="lg:w-2/3 w-full flex flex-col items-evenly pl-8 lg:pl-16 bg-blue-planning-300">
          <blockquote class="max-w-lg mt-auto mx-auto py-8 lg:py-12">
            <p class="mb-4 text-white border-solid border-l-4 border-white pl-4">“I love the way that Picsello flows and so easy to use! All the information I need is easily accessible and well organized. Putting together a proposal for a client is so simple and takes only a few clicks before it's ready to send off for signing and payment.”</p>
            <div class="flex items-center gap-4">
              <img src="https://uploads-ssl.webflow.com/61147776bffed57ff3e884ef/62f45d35be926e94d576f60c_emma.png" alt="Emma Thurgood">
              <cite class="normal not-italic text-white"><span class="block font-bold not-italic">Emma Thurgood</span>
                www.emmathurgood.com</cite>
            </div>
          </blockquote>
          <img class="mt-auto object-cover object-top w-full" style="max-height:75vh;" src="https://uploads-ssl.webflow.com/61147776bffed57ff3e884ef/62f45d6d8aae0229be8bafc7_large-hero.png" alt="Picsello Application" />
        </div>
      </div>
    """
  end

  def container(assigns) do
    ~H"""
    <div class={classes(["flex flex-col items-center justify-center w-screen min-h-screen p-5", @color_class])}>
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <div class="flex items-end justify-between sm:items-center">
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />

          <a title="previous" phx-click="previous" class="cursor-pointer sm:py-2">
            <ul class="flex items-center">
              <%= for step <- 1..3 do %>
                <li class={classes(
                  "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
                  %{ @color_class => step == @step, "bg-gray-200" => step != @step }
                )}>
                </li>
              <% end %>
            </ul>
          </a>
        </div>

        <h1 class="text-3xl font-bold mt-7 sm:leading-tight sm:mt-11"><%= @title %></h1>
        <h2 class="mt-2 mb-2 sm:mb-7 sm:mt-5 sm:text-lg"><%= @subtitle %></h2>
        <%= render_slot(@inner_block) %>
       </div>
    </div>
    """
  end

  def save(%{assigns: %{step: step}} = socket, params, data \\ :skip) do
    save_multi(socket, params, data)
    |> then(fn
      {:ok, %{user: user}} ->
        socket
        |> assign(current_user: user)
        |> assign_step(step + 1)
        |> assign_changeset()

      {:error, reason} ->
        socket |> assign(changeset: reason)
    end)
    |> noreply()
  end

  defdelegate states(), to: Onboardings, as: :state_options
end
