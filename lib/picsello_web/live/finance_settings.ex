defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]
  alias Picsello.{Payments, Accounts.User}

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign_stripe_status()
    |> assign(current_user: current_user)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user} intro_id="intro_settings_finances">
      <div class="flex flex-col justify-between flex-1 flex-grow-0 mt-5 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Finances</h1>
        </div>
      </div>
      <hr class="my-4 sm:my-10" />
      <div class="grid gap-6 sm:grid-cols-2">
        <.card title="Tax info" class="intro-taxes">
          <p class="mt-2">Stripe can easily manage your tax settings to simplify filing.</p>
          <a class="link" target="_blank" href="https://support.picsello.com/article/113-stripe-taxes">Do I need this?</a>
          <div class="flex mt-6 justify-end">
            <%= if @stripe_status == :charges_enabled do %>
              <a class="text-center block btn-primary sm:w-auto w-full" href="https://dashboard.stripe.com/settings/tax" target="_blank" rel="noopener noreferrer">
                View tax settings in Stripe
              </a>
            <% else %>
              <div class="flex flex-col sm:w-auto w-full">
                <button class="btn-primary" disabled>View tax settings in Stripe</button>
                <em class="block pt-1 text-xs text-center">Set up Stripe to view tax settings</em>
              </div>
            <% end %>
          </div>
        </.card>
        <.card title="Stripe account" class="intro-stripe">
          <p class="mt-2">Picsello uses Stripe so your payments are always secure. View and manage your payments through your Stripe account.</p>
          <div class="flex mt-6 justify-end">
            <%= live_component PicselloWeb.StripeOnboardingComponent, id: :stripe_onboarding,
            error_class: "text-right",
            class: "px-8 text-center btn-primary sm:w-auto w-full",
            container_class: "sm:w-auto w-full",
            current_user: @current_user,
            return_url: Routes.home_url(@socket, :index),
            stripe_status: @stripe_status %>
          </div>
        </.card>
        <.card title="Accepted payment types" class="intro-payments">
          <p class="mt-2">Here you can enable if you’d like to accept offline payments. Be careful, you are opening yourself up to more manual work!</p>
          <p class="font-bold mt-4">I would like to accept:</p>
          <div class="flex items-center mt-2 justify-between">
            <div class="flex flex-col">
              <p class="font-semibold">Cash/check payments</p>
              <p class="font-normal flex">Accept offline payments</p>
            </div>
            <div class="flex justify-end items-center">
              <.form for={:toggle} phx-change="toggle">
                <label class="mt-4 text-lg flex">
                  <input type="checkbox" class="peer hidden" checked={User.enabled?(@current_user)}/>
                  <div class="hidden peer-checked:flex cursor-pointer">
                    <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                      <div class="rounded-full h-5 w-5 bg-base-100"></div>
                    </div>
                    Enabled
                  </div>
                  <div class="flex peer-checked:hidden cursor-pointer">
                    <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                      <div class="rounded-full h-5 w-5 bg-blue-planning-300"></div>
                    </div>
                    Disabled
                  </div>
                </label>
              </.form>
            </div>
          </div>
        </.card>
      </div>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  def handle_event(
        "toggle",
        %{},
        %{assigns: %{current_user: %{allow_cash_payment: false}}} = socket
      ) do
    PicselloWeb.ConfirmationComponent.open(socket, %{
      close_event: "toggle_close_event",
      close_label: "No, go back",
      confirm_event: "allow-cash",
      confirm_label: "Yes, allow cash/check",
      icon: "warning-orange",
      title: "Are you sure?",
      subtitle:
        "Are you sure you want to allow cash and checks as a payment option? \n\nYou will need to communicate directly with your client to capture payment and manually enter those into your job payment details."
    })
    |> noreply()
  end

  def handle_event(
        "toggle",
        %{},
        %{assigns: %{current_user: %{allow_cash_payment: true} = current_user}} = socket
      ) do
    socket
    |> assign(current_user: User.toggle(current_user))
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "allow-cash"},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: User.toggle(current_user))
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> noreply()
  end

  def handle_info(
        {:close_event, "toggle_close_event"},
        socket
      ) do
    socket
    |> push_redirect(to: Routes.finance_settings_path(socket, :index))
    |> close_modal()
    |> noreply()
  end

  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end
end
