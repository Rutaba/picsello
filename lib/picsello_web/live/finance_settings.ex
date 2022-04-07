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
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user}>
      <div class="flex flex-col justify-between flex-1 flex-grow-0 mt-5 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Finances</h1>
        </div>
      </div>
      <hr class="my-4 sm:my-10" />
      <div class="flex grid flex-row justify-between flex-1 flex-grow-0 gap-6 sm:grid-cols-2">
        <div class="flex flex-row">
          <.card title="Stripe Account">
            <p class="mt-10">Picsello uses Stripe so your payments are always secure. View and manage your payments through your Stripe account.</p>
            <div class="mt-10 text-right">
              <%= live_component PicselloWeb.StripeOnboardingComponent, id: :stripe_onboarding,
              erorr_class: "text-right",
              class: "px-8 text-center btn-primary",
              current_user: @current_user,
              return_url: Routes.home_url(@socket, :index),
              stripe_status: @stripe_status %>
            </div>
          </.card>
        </div>
      </div>
    </.settings_nav>
    """
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end
end
