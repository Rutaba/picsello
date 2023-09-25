defmodule PicselloWeb.OnboardingLive.Mastermind.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: :onboarding]

  alias Picsello.{Repo, Onboardings, Onboardings.Onboarding, Subscriptions, UserCurrency}

  import PicselloWeb.OnboardingLive.Shared, only: [signup_container: 1, signup_deal: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:main_class, "bg-gray-100")
    |> assign(:step_total, 4)
    |> assign_step()
    |> assign(:loading_stripe, false)
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

  # @impl true
  # def handle_event("save", %{"user" => params}, %{assigns: %{step: 3}} = socket) do
  #   save_final(socket, params)
  # end

  # @impl true
  # def handle_event("save", %{"user" => params}, socket) do
  #   save(socket, params)
  # end

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
      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" id={"onboarding-step-#{@step}"}>
        <.step f={f} {assigns} />
      </.form>
    """
  end

  defp step(%{step: 2} = assigns) do
    ~H"""
      <.signup_container {assigns} show_logout?={true}>
        <h2>Picsello’s Business Mastermind is here to help you achieve success on your terms</h2>
        <blockqoute>
          <p>
            "Jane has been a wonderful mentor! With her help I’ve learned the importance of believing in myself and my work. She has taught me that it is imperative to be profitable at every stage of my photography journey to ensure I’m set up for lasting success. Jane has also given me the tools I need to make sure I’m charging enough to be profitable. She is always there to answer my questions and cheer me on. Jane has played a key role in my growth as a photographer and business owner! I wouldn’t be where I am without her!”
          </p>
          <cite>
            - Kelsey, Kelsey Renee Photography
          </cite>
        </blockqoute>
        <:right_panel>
          <.signup_deal original_price={Money.new(35000, :USD)} price={Money.new(24500, :USD)} expires_at="22 days, 1 hour, 15 seconds" />
          <h1>form</h1>
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step(%{step: 3} = assigns) do
    ~H"""
      <.signup_container {assigns} show_logout?={true}>
        <h2>Picsello’s Business Mastermind is here to help you achieve success on your terms</h2>
        <blockqoute>
          <p>
            "Jane has been a wonderful mentor! With her help I’ve learned the importance of believing in myself and my work. She has taught me that it is imperative to be profitable at every stage of my photography journey to ensure I’m set up for lasting success. Jane has also given me the tools I need to make sure I’m charging enough to be profitable. She is always there to answer my questions and cheer me on. Jane has played a key role in my growth as a photographer and business owner! I wouldn’t be where I am without her!”
          </p>
          <cite>
            - Kelsey, Kelsey Renee Photography
          </cite>
        </blockqoute>
        <:right_panel>
          <.signup_deal original_price={Money.new(35000, :USD)} price={Money.new(24500, :USD)} expires_at="22 days, 1 hour, 15 seconds" />
          <h1>form</h1>
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step(%{step: 4} = assigns) do
    ~H"""
      <.signup_container {assigns} show_logout?={true}>
        <h2>Picsello’s Business Mastermind is here to help you achieve success on your terms</h2>
        <blockqoute>
          <p>
            "Jane has been a wonderful mentor! With her help I’ve learned the importance of believing in myself and my work. She has taught me that it is imperative to be profitable at every stage of my photography journey to ensure I’m set up for lasting success. Jane has also given me the tools I need to make sure I’m charging enough to be profitable. She is always there to answer my questions and cheer me on. Jane has played a key role in my growth as a photographer and business owner! I wouldn’t be where I am without her!”
          </p>
          <cite>
            - Kelsey, Kelsey Renee Photography
          </cite>
        </blockqoute>
        <:right_panel>
          <.signup_deal original_price={Money.new(35000, :USD)} price={Money.new(24500, :USD)} expires_at="22 days, 1 hour, 15 seconds" />
          <h1>form</h1>
          <.step_footer {assigns} />
        </:right_panel>
      </.signup_container>
    """
  end

  defp step_footer(assigns) do
    ~H"""
    <div class="flex items-center justify-between mt-5 sm:justify-end sm:mt-9" phx-hook="HandleTrialCode" id="handle-trial-code" data-handle="retrieve">
      <%= if @step > 2 do %>
        <button type="button" phx-click="previous" class="flex-grow px-6 sm:flex-grow-0 btn-secondary sm:px-8">
          Back
        </button>
      <% end %>
      <button type="submit" phx-disable-with="Saving" disabled={!@changeset.valid? || @loading_stripe} class="flex-grow px-6 ml-4 sm:flex-grow-0 btn-primary sm:px-8">
        <%= if @step == 3, do: "Start Trial", else: "Next" %>
      </button>
    </div>
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
      step_title: "Get the deal",
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

  defp build_changeset(%{assigns: %{current_user: user, step: step}}, params, action \\ nil) do
    user
    |> Onboardings.changeset(params, step: step)
    |> Map.put(:action, action)
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(changeset: build_changeset(socket, params, :validate))
  end

  defdelegate states(), to: Onboardings, as: :state_options
end
