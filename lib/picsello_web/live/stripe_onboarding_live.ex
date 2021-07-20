defmodule PicselloWeb.StripeOnboardingLive do
  @moduledoc false

  use PicselloWeb, :live_view

  require Logger

  @impl true
  def mount(_params, %{"return_url" => return_url} = session, socket) do
    if connected?(socket), do: send(self(), :load_status)

    socket
    |> assign_defaults(session)
    |> assign(status: :loading, return_url: return_url)
    |> ok()
  end

  @impl true
  def render(assigns) do
    case assigns do
      %{status: :loading} ->
        ~L"""
        <div class="flex items-center justify-center w-full m-2 mt-8 text-xs">
          <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-primary animate-ping"></div>
          Loading...
        </div>
        """

      %{status: {:ok, :charges_enabled}} ->
        ~L""

      _ ->
        ~L"""
        <button type="button" phx-click="init-stripe" class="w-full mt-8 btn-primary">
          Create Stripe Account
        </button>
        """
    end
  end

  @impl true
  def handle_info(:load_status, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(:status, Picsello.Payments.status(current_user))
    |> noreply()
  end

  @impl true
  def handle_info(
        :link_stripe,
        %{assigns: %{current_user: current_user, return_url: return_url}} = socket
      ) do
    refresh_url = socket |> Routes.user_settings_url(:stripe_refresh)

    case Picsello.Payments.link(current_user, refresh_url: refresh_url, return_url: return_url) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't link stripe account.") |> noreply()
    end
  end

  @impl true
  def handle_event(
        "init-stripe",
        %{},
        socket
      ) do
    send(self(), :link_stripe)
    socket |> assign(status: :loading) |> noreply()
  end
end
