defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  alias PicselloWeb.Endpoint
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  @spec mount(
          map(),
          map(),
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    url = Routes.i_calendar_url(socket, :index, Phoenix.Token.sign(Endpoint, "USER_ID", user.id))

    socket
    |> assign(%{
      url: url
    })
    |> assign_from_token(user)
    |> ok()
  end

  @impl true
  @spec handle_event(String.t(), any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("disconnect_calendar", _, %{assigns: %{current_user: user}} = socket) do
    user = %{nylas_oauth_token: nil} = Accounts.clear_user_nylas_code(user)

    {:noreply, socket |> assign_from_token(user)}
  end

  @spec assign_from_token(Phoenix.LiveView.Socket.t(), %{:nylas_oauth_token => String.t() | nil}) ::
          Phoenix.LiveView.Socket.t()
  def assign_from_token(socket, %{nylas_oauth_token: nil}) do
    socket |> assign(has_token: false, token: nil)
  end

  def assign_from_token(socket, %{nylas_oauth_token: token}) do
    socket |> assign(%{has_token: true, token: token})
  end
end
