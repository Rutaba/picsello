defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]

  alias Picsello.Payments

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
          <a class="link" href="javascript:void(0);" {help_scout_output(@current_user, :help_scout_id)} data-article="625878185d0b9565e1733f7e">Do I need this?</a>
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
      </div>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end
end
