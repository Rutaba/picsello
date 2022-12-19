defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  import Picsello.Zapier.User, only: [user_trial_created_webhook: 1]
  use PicselloWeb, live_view: [layout: :onboarding]
  require Logger

  alias Ecto.Multi
  alias Picsello.{Repo, JobType, Onboardings, Subscriptions}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_step(2)
    |> assign(:loading_stripe, false)
    |> assign(
      :subscription_plan_metadata,
      Subscriptions.get_subscription_plan_metadata()
    )
    |> assign_new(:job_types, &job_types/0)
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
        <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"onboarding-step-#{@step}"}>
          <.step f={f} {assigns} />

          <div class="flex items-center justify-between mt-5 sm:justify-end sm:mt-9" phx-hook="HandleTrialCode" id="handle-trial-code" data-handle="retrieve">
            <%= if @step > 2 do %>
              <button type="button" phx-click="previous" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
                Back
              </button>
            <% else %>
              <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete, class: "flex-grow sm:flex-grow-0 underline mr-auto text-left") %>
            <% end %>
            <button type="submit" phx-disable-with="Saving" disabled={!@changeset.valid? || @loading_stripe} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">
              <%= if @step == 3, do: "Start Trial", else: "Next" %>
            </button>
          </div>
        </.form>
      </.container>
    """
  end

  defp step(%{step: 2} = assigns) do
    ~H"""
      <%= for org <- inputs_for(@f, :organization) do %>
        <%= hidden_inputs_for org %>

        <label class="flex flex-col">
          <p class="py-2 font-extrabold">What’s the name of your photography business?</p>

          <%= input org, :name, phx_debounce: "500", placeholder: "Business name", class: "p-4" %>
          <%= error_tag org, :name, prefix: "Photography business name", class: "text-red-sales-300 text-sm" %>
        </label>
      <% end %>

      <%= for onboarding <- inputs_for(@f, :onboarding) do %>

        <div class="grid sm:grid-cols-2 gap-4">
          <label class="flex flex-col mt-4">
            <p class="py-2 font-extrabold">Are you a full-time or part-time photographer?</p>

            <%= select onboarding, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select p-4" %>
          </label>

          <label class="flex flex-col mt-4">
            <p class="py-2 font-extrabold">How many years have you been a photographer?</p>

            <%= input onboarding, :photographer_years, type: :number_input, phx_debounce: 500, min: 0, placeholder: "e.g. 0, 1, 2, etc.", class: "p-4" %>
            <%= error_tag onboarding, :photographer_years, class: "text-red-sales-300 text-sm" %>
          </label>
        </div>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">Where’s your business based?</p>

          <%= select onboarding, :state, [{"select one", nil}] ++ @states, class: "select p-4" %>
          <%= error_tag onboarding, :state, class: "text-red-sales-300 text-sm" %>
        </label>
      <% end %>
    """
  end

  defp step(%{step: 3} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :organization) do %>
        <%= hidden_inputs_for o %>

        <%= for p <- inputs_for(o, :profile) do %>
          <% input_name = input_name(p, :job_types) <> "[]" %>
          <div class="flex flex-col pb-1">
            <p class="py-2 font-extrabold">
              What’s your speciality?
              <i class="italic font-light">(Select one or more)</i>
            </p>

            <div data-rewardful-email={@current_user.email} id="rewardful-email"></div>

            <div class="mt-2 grid grid-cols-2 gap-3 sm:gap-5">
              <%= for(job_type <- job_types(), checked <- [Enum.member?(input_value(p, :job_types) || [], job_type)]) do %>
                <.job_type_option type="checkbox" name={input_name} job_type={job_type} checked={checked} />
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    """
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
      step_title: "Customize your account",
      subtitle: "",
      page_title: "Onboarding Step 3"
    )
  end

  defp build_changeset(%{assigns: %{current_user: user, step: step}}, params, action \\ nil) do
    user
    |> Onboardings.changeset(params, step: step)
    |> Map.put(:action, action)
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  def optimized_container(assigns) do
    ~H"""
      <div class="flex items-stretch w-screen min-h-screen flex-wrap">
        <div class="lg:w-1/3 w-full flex flex-col justify-center px-8 lg:px-16 py-8">
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
          <%= render_block(@inner_block) %>
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

          <a title="previous" href="#" phx-click="previous" class="cursor-pointer sm:py-2">
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
        <%= render_block(@inner_block) %>
       </div>
    </div>
    """
  end

  @impl true
  def handle_info({:stripe_session_id, stripe_session_id}, socket) do
    case Subscriptions.handle_subscription_by_session_id(stripe_session_id) do
      :ok ->
        socket
        |> assign(current_user: Onboardings.complete!(socket.assigns.current_user))
        |> update_user_contact_trial(socket.assigns.current_user)
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Couldn't fetch your Stripe session. Please try again")
        |> noreply()
    end
  end

  defp update_user_contact_trial(socket, current_user) do
    %{
      list_ids: SendgridClient.get_all_contact_list_env(),
      contacts: [
        %{
          email: current_user.email,
          state_province_region: current_user.onboarding.state,
          custom_fields: %{
            w3_T: current_user.organization.name,
            w1_T: "trial"
          }
        }
      ]
    }
    |> SendgridClient.add_contacts()

    user_trial_created_webhook(%{email: current_user.email})

    socket
  end

  defp save(%{assigns: %{step: step}} = socket, params, data \\ :skip) do
    Multi.new()
    |> Multi.put(:data, data)
    |> Multi.update(:user, build_changeset(socket, params))
    |> Repo.transaction()
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

  defp save_final(socket, params, data \\ :skip) do
    Multi.new()
    |> Multi.put(:data, data)
    |> Multi.update(:user, build_changeset(socket, params))
    |> Multi.run(:subscription, fn _repo, %{user: user} ->
      with :ok <-
             Subscriptions.subscription_base(user, "month",
               trial_days: socket.assigns.subscription_plan_metadata.trial_length
             )
             |> Picsello.Subscriptions.handle_stripe_subscription() do
        {:ok, nil}
      end
    end)
    |> Multi.run(:user_final, fn _repo, %{user: user} ->
      with _ <- Onboardings.complete!(user) do
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{user: user}} ->
        socket
        |> assign(current_user: user)
        |> update_user_contact_trial(user)
        |> push_redirect(to: Routes.home_path(socket, :index, new_user: true), replace: true)

      {:error, reason} ->
        socket |> assign(changeset: reason)
    end)
    |> noreply()
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate states(), to: Onboardings, as: :state_options
end
