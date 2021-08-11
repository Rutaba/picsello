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
  def handle_info(:load_status, %{assigns: %{current_user: current_user}} = socket) do
    case payments().status(current_user) do
      {:ok, status} ->
        if socket.parent_pid, do: send(socket.parent_pid, {:stripe_status, status})
        socket |> assign(status: status) |> noreply()

      error ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't reach stripe.") |> noreply()
    end
  end

  @impl true
  def handle_info(
        :link_stripe,
        %{assigns: %{current_user: current_user, return_url: return_url}} = socket
      ) do
    refresh_url = socket |> Routes.user_settings_url(:stripe_refresh)

    case payments().link(current_user, refresh_url: refresh_url, return_url: return_url) do
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
    socket |> assign(status: :redirecting) |> noreply()
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
