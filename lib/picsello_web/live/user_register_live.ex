defmodule PicselloWeb.UserRegisterLive do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "onboarding"]

  alias Picsello.{Accounts, Accounts.User}
  import PicselloWeb.OnboardingLive.Index, only: [optimized_container: 1]

  import Picsello.Subscriptions,
    only: [get_subscription_plan_metadata: 0, get_subscription_plan_metadata: 1]

  import PicselloWeb.OnboardingLive.Shared, only: [signup_container: 1, signup_deal: 1]

  @steps [1, 2, 3, 4]

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign(:main_class, "bg-gray-100")
    |> assign_defaults(session)
    |> assign(:onboarding_type, nil)
    |> assign(step: 1, steps: @steps)
    |> assign(
      :subscription_plan_metadata,
      get_subscription_plan_metadata()
    )
    |> assign(%{
      page_title: "Sign Up",
      meta_attrs: %{
        description:
          "This is going to be a game changer! Get signed up and start growing your business. Register with Picsello and start managing, marketing, and monetizing your photography business today."
      }
    })
    |> assign_changeset()
    |> assign_trigger_submit()
    |> ok()
  end

  @impl true
  def handle_params(%{"code" => code}, _uri, socket) do
    socket
    |> assign(
      :subscription_plan_metadata,
      get_subscription_plan_metadata(code)
    )
    |> noreply()
  end

  @impl true
  def handle_params(%{"onboarding_type" => onboarding_type}, _uri, socket) do
    socket
    |> assign(:onboarding_type, onboarding_type)
    |> noreply()
  end

  def handle_params(_params, _uri, socket), do: noreply(socket)

  @impl true
  def handle_event("validate", %{"user" => %{"trigger_submit" => "true"}}, socket),
    do: noreply(socket)

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    params = Map.put(params, "onboarding_flow_source", [socket.assigns.onboarding_type])

    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("previous", %{}, socket), do: noreply(socket)

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "onboarding_flow_source", [socket.assigns.onboarding_type])

    socket
    |> assign_changeset(user_params, :validate)
    |> assign_trigger_submit()
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <.onboarding_view {assigns} />
    """
  end

  defp onboarding_view(%{onboarding_type: nil} = assigns) do
    ~H"""
      <.optimized_container step={@step} steps={@steps} color_class="bg-blue-planning-200">
        <.signup_hooks />
        <h1 class="text-3xl font-bold sm:leading-tight mt-2"><%= @subscription_plan_metadata.signup_title %></h1>
        <h2 class="text-base mt-4 font-normal"><%= @subscription_plan_metadata.signup_description %> or <%= link "log in", to: Routes.user_session_path(@socket, :new), class: "underline text-blue-planning-300" %>.</h2>
        <.signup_form {assigns} />
      </.optimized_container>
    """
  end

  defp onboarding_view(%{onboarding_type: "mastermind"} = assigns) do
    ~H"""
      <.signup_container {assigns} step={1} step_total={length(@steps)} step_title="Let’s get to know you" left_classes="p-8 pb-0 bg-purple-marketing-300 text-white">
        <h2 class="text-3xl md:text-4xl font-bold text-center mb-2">
          Join Picsello’s
          <br />
          <span class="underline underline-offset-1 text-decoration-blue-planning-300">Business Mastermind</span>
        </h2>
        <p class="text-xl text-center">Build a strong foundation for every part of your business so it supports growth and sustainable profit.</p>
        <div class="max-w-md mx-auto my-8">
          <.signup_deal original_price={Money.new(35000, :USD)} price={Money.new(24500, :USD)} expires_at="22 days, 1 hour, 15 seconds" />
        </div>
        <ul class="mb-8 space-y-2">
          <li class="flex gap-2"><.icon name="checkcircle" class="h-4 w-4 flex-shrink-0 mt-1.5" /> 1 x a month expert session with Q&As</li>
          <li class="flex gap-2"><.icon name="checkcircle" class="h-4 w-4 flex-shrink-0 mt-1.5" /> 1 x a month hot seat - ask Jane anything</li>
          <li class="flex gap-2"><.icon name="checkcircle" class="h-4 w-4 flex-shrink-0 mt-1.5" /> Private community where you can connect with photographers who have shared experiences</li>
          <li class="flex gap-2"><.icon name="checkcircle" class="h-4 w-4 flex-shrink-0 mt-1.5" /> 1:1 access to Jane and the Picsello coaches</li>
          <li class="flex gap-2"><.icon name="checkcircle" class="h-4 w-4 flex-shrink-0 mt-1.5" /> 1 year of the entire Picsello Platform</li>
        </ul>
        <img src={Routes.static_path(@socket, "/images/mastermind-hero.png")} loading="lazy" alt="Images of the Picsello App" />
        <:right_panel>
          <.signup_hooks />
          <.signup_form {assigns} form_classes="flex-grow" />
        </:right_panel>
      </.signup_container>
    """
  end

  defp signup_form(assigns) do
    assigns = Enum.into(assigns, %{
      form_classes: ""
    })
    ~H"""
      <a href={Routes.auth_path(@socket, :request, :google)} class="flex items-center justify-center w-full mt-8 text-center btn-primary">
        <.icon name="google" width="25" height="24" class="mr-4" />
        Continue with Google
      </a>
      <p class="m-6 text-center">or</p>
      <.form :let={f} for={@changeset} action={Routes.user_registration_path(@socket, :create)} phx-change="validate" phx-submit="save" phx-trigger-action={@trigger_submit} class={"flex flex-col #{@form_classes}"}>
        <%= hidden_input f, :trigger_submit, value: @trigger_submit %>
        <%= hidden_input f, :onboarding_flow_source, value: @onboarding_type %>
        <%= labeled_input f, :name, placeholder: "Jack Nimble", phx_debounce: "500", label: "Your first & last name", autocomplete: "name" %>
        <%= labeled_input f, :email, type: :email_input, placeholder: "jack.nimble@example.com", phx_debounce: "500", wrapper_class: "mt-4" %>
        <%= live_component PicselloWeb.PasswordFieldComponent, f: f, id: :register_password, placeholder: "something secret"%>

        <p class="text-sm text-gray-400 mt-6 sm:pr-6 mb-8">By signing up you agree to our
          <a href="https://www.picsello.com/privacy-policy" target="_blank" rel="noopener noreferrer" class="border-b border-gray-400">Privacy Policy</a> and
          <a href="https://www.picsello.com/terms-conditions" target="_blank" rel="noopener noreferrer" class="border-b border-gray-400">Terms</a>
        </p>

        <div class="flex mt-auto">
          <%= submit "Sign up",
            class: "btn-primary sm:flex-1 px-6 sm:px-10 flex-grow",
            disabled: !@changeset.valid?,
            phx_disable_with: "Saving..."
          %>
        </div>
      </.form>
    """
  end

  defp signup_hooks(assigns) do
    ~H"""
      <div id="tz-cookie" phx-hook="TZCookie"></div>
      <div phx-hook="HandleTrialCode" id="handle-trial-code" data-handle="save"></div>
    """
  end

  defp assign_trigger_submit(%{assigns: %{changeset: changeset}} = socket) do
    socket |> assign(trigger_submit: changeset.valid?)
  end

  defp assign_changeset(socket, params \\ %{}, action \\ nil) do
    socket
    |> assign(
      changeset: Accounts.change_user_registration(%User{}, params) |> Map.put(:action, action)
    )
  end
end
