defmodule PicselloWeb.OnboardingLive.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]
  require Logger
  alias Picsello.{Repo, JobType, Onboardings, Subscriptions, Accounts.User}

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign_step(2)
    |> assign(:loading_stripe, false)
    |> assign_new(:job_types, &job_types/0)
    |> assign_changeset()
    |> maybe_show_trial(params)
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
  def handle_event("save", %{}, %{assigns: %{step: 6}} = socket) do
    case Subscriptions.checkout_link(
           socket.assigns.current_user,
           "month",
           success_url:
             "#{Routes.onboarding_url(socket, :index)}?session_id={CHECKOUT_SESSION_ID}",
           cancel_url: Routes.onboarding_url(socket, :index, step: "trial"),
           trial_days: 30
         ) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.warning("Error redirecting to Stripe: #{inspect(error)}")
        socket |> put_flash(:error, "Couldn't redirect to Stripe. Please try again") |> noreply()
    end
  end

  @impl true
  def handle_event("save", %{"user" => params}, %{assigns: %{step: step}} = socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, user} ->
        socket
        |> assign(current_user: user)
        |> assign_step(step + 1)
        |> assign_changeset()
        |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event("go-dashboard", %{}, socket) do
    socket
    |> push_redirect(to: Routes.home_path(socket, :index), replace: true)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.container step={@step} color_class={@color_class} title={@step_title} subtitle={@subtitle}>
        <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"onboarding-step-#{@step}"}>
          <.step f={f} {assigns} />

          <div class="flex justify-between mt-5 sm:justify-end sm:mt-9 items-center">
            <%= if @step > 2 do %>
              <button type="button" phx-click="previous" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
                Back
              </button>
            <% else %>
              <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete, class: "flex-grow sm:flex-grow-0 underline mr-auto text-left") %>
            <% end %>
            <button type="submit" phx-disable-with="Saving" disabled={!@changeset.valid? || @loading_stripe} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">
              <%= if @step == 6, do: "Start Trial", else: "Next" %>
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

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">Are you a full-time or part-time photographer?</p>

          <%= select onboarding, :schedule, %{"Full-time" => :full_time, "Part-time" => :part_time}, class: "select p-4" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">How many years have you been a photographer?</p>

          <%= input onboarding, :photographer_years, type: :number_input, phx_debounce: 500, min: 0, placeholder: "e.g. 0, 1, 2, etc.", class: "p-4" %>
          <%= error_tag onboarding, :photographer_years, class: "text-red-sales-300 text-sm" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">Where’s your business based?</p>

          <%= select onboarding, :state, [{"select one", nil}] ++ @states, class: "select p-4" %>
          <%= error_tag onboarding, :state, class: "text-red-sales-300 text-sm" %>
        </label>

        <label class="flex flex-col mt-4">
          <p class="py-2 font-extrabold">What's your phone number?</p>

          <%= input onboarding, :phone, type: :telephone_input, phx_debounce: 500, placeholder: "(555) 555-5555", phx_hook: "Phone", class: "p-4" %>
          <%= error_tag onboarding, :phone, class: "text-red-sales-300 text-sm", prefix: "Phone number" %>
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

  defp step(%{step: 4} = assigns) do
    ~H"""
      <%= for o <- inputs_for(@f, :organization) do %>
        <%= hidden_inputs_for o %>

        <%= for p <- inputs_for(o, :profile) do %>
          <label class="flex flex-col">
            <p class="py-2 font-extrabold">Choose your color <i class="italic font-light">(Used to customize your invoices, emails, and profile)</i></p>
            <ul class="mt-2 grid grid-cols-4 gap-5 sm:gap-3 sm:grid-cols-8">
              <%= for(color <- colors()) do %>
                <li class="aspect-h-1 aspect-w-1">
                  <label>
                    <%= radio_button p, :color, color, class: "hidden" %>
                    <div class={classes(
                      "flex cursor-pointer items-center hover:border-base-300 justify-center w-full h-full border rounded", %{
                      "border-base-300" => input_value(p, :color) == color,
                      "hover:border-opacity-40" => input_value(p, :color) != color
                    })}>
                      <div class="w-4/5 rounded h-4/5" style={"background-color: #{color}"}></div>
                    </div>
                  </label>
                </li>
              <% end %>
            </ul>
          </label>

          <.website_field form={p} class="mt-4" />
        <% end %>
      <% end %>
    """
  end

  defp step(%{step: 5} = assigns) do
    software_selected? = fn form, software ->
      Enum.member?(input_value(form, :switching_from_softwares) || [], software)
    end

    ~H"""
      <%= for o <- inputs_for(@f, :onboarding) do %>
        <div class="flex flex-col pb-1">
          <p class="py-2 font-extrabold">
            Which photography software have you used before?
            <i class="font-normal">(Select one or more)</i>
          </p>

          <div class="mt-2 grid grid-cols-2 gap-3 sm:gap-5">
            <%= for({value, label} <- software_options(), checked <- [software_selected?.(o, value)]) do %>
              <label class={classes(
                "p-3 border rounded-lg hover:bg-blue-planning-100 hover:bg-opacity-60 cursor-pointer font-semibold text-sm sm:text-base",
                %{"border-blue-planning-300 bg-blue-planning-100" => checked}
              )}>
                <input class="hidden" type={if software_selected?.(o, :none), do: "radio", else: "checkbox"} name={input_name(o, :switching_from_softwares) <> "[]"} value={value} checked={checked} />

                <%= label %>
              </label>
            <% end %>
          </div>
        </div>
      <% end %>
    """
  end

  defp step(%{step: 6} = assigns) do
    ~H"""
    <%= for org <- inputs_for(@f, :organization) do %>
      <%= hidden_inputs_for org %>
    <% end %>

    <hr class="mb-4" />
    <p class="font-bold">Why do you need my credit card for a trial?</p>
    <p>We want to keep Picsello as secure and fraud free as possible. You can cancel your plan at anytime during and after your trial.</p>
    <hr class="my-4" />
    <p class="font-bold">When will I be charged?</p>
    <p>After 1-month, your subscription will be $50/month. (You can change to annual if you prefer in account settings.)</p>
    <div data-rewardful-email={@current_user.email} id="rewardful-email"></div>

    <%= if User.onboarded?(@current_user) do %>
      <div class="fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center">
        <div class="dialog rounded-lg">
          <.icon name="confetti" class="w-11 h-11" />

          <h1 class="text-3xl font-semibold">Your 1-month free trial has started!</h1>
          <p class="pt-4">We’re excited to have you try Picsello. You can always manage your subscription in account settings. If you have any trouble, contact support.</p>

          <button class="w-full mt-6 btn-primary" type="button" phx-click="go-dashboard">
            Go to my dashboard
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  defdelegate software_options(), to: Onboardings

  defp assign_step(socket, 2) do
    socket
    |> assign(
      step: 2,
      color_class: "bg-orange-inbox-200",
      step_title: "Tell us more about yourself",
      subtitle: "We need a little more info to get your account ready!",
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

  defp assign_step(socket, 4) do
    socket
    |> assign(
      step: 4,
      color_class: "bg-green-finances-100",
      step_title: "Customize your account",
      subtitle: "",
      page_title: "Onboarding Step 4"
    )
  end

  defp assign_step(socket, 5) do
    socket
    |> assign(
      step: 5,
      color_class: "bg-blue-planning-200",
      step_title: "Almost done!",
      subtitle: "",
      page_title: "Onboarding Step 5"
    )
  end

  defp assign_step(socket, 6) do
    socket
    |> assign(
      step: 6,
      color_class: "bg-blue-gallery-200",
      step_title: "Start your 1-month free trial",
      subtitle:
        "Explore and learn Picsello at your own pace. Pricing simplified. One plan, all features.",
      page_title: "Onboarding Step 6"
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

  def container(assigns) do
    ~H"""
    <div class={classes(["flex flex-col items-center justify-center w-screen min-h-screen p-5", @color_class])}>
      <div class="container px-6 pt-8 pb-6 bg-white rounded-lg shadow-md max-w-screen-sm sm:p-14">
        <div class="flex items-end justify-between sm:items-center">
          <.icon name="logo" class="w-32 h-7 sm:h-11 sm:w-48" />

          <a title="previous" href="#" phx-click="previous" class="cursor-pointer sm:py-2">
            <ul class="flex items-center">
              <%= for step <- 1..6 do %>
                <li class={classes(
                  "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
                  %{ @color_class => step == @step, "bg-gray-200" => step != @step }
                )}>
                </li>
              <% end %>
            </ul>
          </a>
        </div>

        <h1 class="text-3xl font-bold sm:text-5xl mt-7 sm:leading-tight sm:mt-11"><%= @title %></h1>
        <h2 class="mt-2 mb-2 sm:mb-7 sm:mt-5 sm:text-2xl"><%= @subtitle %></h2>
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

  defp maybe_show_trial(socket, %{
         "session_id" => "" <> session_id
       }) do
    if connected?(socket),
      do: send(self(), {:stripe_session_id, session_id})

    socket
    |> assign(:loading_stripe, true)
    |> assign_step(6)
  end

  defp maybe_show_trial(socket, %{"step" => "trial"}) do
    if socket.assigns.changeset.valid? do
      socket
      |> assign_step(6)
    else
      socket
    end
  end

  defp maybe_show_trial(socket, %{}), do: socket

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

    socket
  end

  defdelegate job_types(), to: JobType, as: :all
  defdelegate colors(), to: Picsello.Profiles
  defdelegate states(), to: Onboardings, as: :state_options
end
