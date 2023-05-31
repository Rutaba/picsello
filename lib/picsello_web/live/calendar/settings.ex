defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  alias PicselloWeb.Endpoint
  alias Phoenix.LiveView.Socket
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
      token: "",
      rw_calendar: nil,
      read_calendars: MapSet.new()
    })
    |> assign_from_token(user)
    |> ok()
  end

  @impl true
  @spec handle_event(String.t(), any, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event(
        "disconnect_calendar",
        _,
        %Socket{assigns: %{current_user: %Picsello.Accounts.User{} = user}} =
          socket
      ) do
    user = %{nylas_oauth_token: nil} = Accounts.clear_user_nylas_code(user)

    {:noreply, socket |> assign_from_token(user)}
  end

  def handle_event(
        "calendar-read",
        %{"calendar" => cal_id, "checked" => "no"},
        %Socket{assigns: %{read_calendars: read_calendars}} = socket
      ) do
    Logger.info("Calendar id \e[0;35m#{cal_id} true\e[0;30m")
    {:noreply, assign(socket, :read_calendars, MapSet.put(read_calendars, cal_id))}
  end

  def handle_event(
        "calendar-read",
        %{"calendar" => cal_id, "checked" => "yes"},
        %Socket{assigns: %{read_calendars: read_calendars}} = socket
      ) do
    Logger.info("Calendar id \e[0;34m#{cal_id} false \e[0;30m")
    {:noreply, assign(socket, :read_calendars, MapSet.delete(read_calendars, cal_id))}
  end

  def handle_event("calendar-read-write", %{"calendar" => cal_id}, socket) do
    Logger.info("Calendar id \e[0;32m#{cal_id}\e[0;30m")
    {:noreply, assign(socket, :rw_calendar, cal_id)}
  end

  def handle_event(
        "save",
        _,
        %Socket{
          assigns: %{read_calendars: read_calendars, rw_calendar: rw_calendar, current_user: user}
        } = socket
      ) do
    Picsello.Accounts.User.set_nylas_calendars(user, %{
      external_calendar_rw_id: rw_calendar,
      external_calendar_read_list: MapSet.to_list(read_calendars)
    })

    {:noreply, socket}
  end

  def handle_event(
        cmd,
        msg,
        %Socket{assigns: _read_calendars} = socket
      ) do
    Logger.info("\e[0;34m#{cmd} -- #{inspect(msg)}\e[0;30m")
    {:noreply, socket}
  end

  @spec is_member(MapSet.t(), any) :: String.t()
  def is_member(calendars, cal_id) do
    if MapSet.member?(calendars, cal_id) do
      "yes"
    else
      "no"
    end
  end

  @spec assign_from_token(Socket.t(), nil | Picsello.Accounts.User.t()) :: Socket.t()
  def assign_from_token(socket, %Picsello.Accounts.User{nylas_oauth_token: token})
      when is_binary(token) do
    case NylasCalendar.get_calendars(token) do
      {:ok, calendars} ->
        assign(socket, %{has_token: true, token: token, calendars: calendars})

      {:error, msg} ->
        assign(socket, %{error: msg})
    end
  end

  def assign_from_token(socket, _) do
    socket
  end
end
