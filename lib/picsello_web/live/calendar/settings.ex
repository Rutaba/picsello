defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  alias PicselloWeb.Endpoint
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  require Logger
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
      url: url,
      error: false,
      calendars: [],
      has_token: false,
      token: ""
    })
    |> assign_from_token(user)
    |> ok()
  end

  @impl true
  @spec handle_event(String.t(), any, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event(
        "disconnect_calendar",
        _,
        %{assigns: %{current_user: %Picsello.Accounts.User{} = user}} = socket
      ) do
    user = %{nylas_oauth_token: nil} = Accounts.clear_user_nylas_code(user)

    {:noreply, socket |> assign_from_token(user)}
  end

  def handle_event("calendar-read", %{"calendar" => cal_id}, socket) do
    Logger.info("Calendar id \e[0;34m#{cal_id}\e[0;30m")
    {:noreply, socket}
  end

  def handle_event("calendar-read-write", %{"calendar" => cal_id}, socket) do
    Logger.info("Calendar id \e[0;32m#{cal_id}\e[0;30m")
    {:noreply, socket}
  end

  @spec assign_from_token(Phoenix.LiveView.Socket.t(), Picsello.Accounts.User.t()) ::
          Phoenix.LiveView.Socket.t()
  def assign_from_token(socket, %Picsello.Accounts.User{nylas_oauth_token: nil}) do
    socket
  end

  def assign_from_token(socket, %Picsello.Accounts.User{nylas_oauth_token: token})
      when is_binary(token) do
    case NylasCalendar.get_calendars(token) do
      {:ok, calendars} ->
        assign(socket, %{has_token: true, token: token, calendars: calendars})

      {:error, msg} ->
        assign(socket, %{error: msg})
    end
  end
end
