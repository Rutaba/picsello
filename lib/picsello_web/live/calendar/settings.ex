defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Accounts
  alias PicselloWeb.Endpoint
  alias Phoenix.LiveView.Socket
  import PicselloWeb.Live.Calendar.Shared
  require Logger
  @impl true
  @spec mount(
          map(),
          map(),
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    url = Routes.i_calendar_url(socket, :index, Phoenix.Token.sign(Endpoint, "USER_ID", user.id))
    {:ok, nylas_url} = NylasCalendar.generate_login_link()

    socket
    |> assign(%{
      url: url,
      error: false,
      calendars: [],
      has_token: false,
      token: "",
      nylas_url: nylas_url,
      rw_calendar: user.external_calendar_rw_id,
      read_calendars: to_set(user)
    })
    |> assign_from_token(user)
    |> ok()
  end

  defp to_set(%{external_calendar_read_list: nil}) do
    MapSet.new([])
  end

  defp to_set(%{external_calendar_read_list: list}) do
    MapSet.new(list)
  end

  @impl true
  @spec handle_event(String.t(), any, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event(
        "disconnect_calendar",
        _,
        %Socket{assigns: %{current_user: %Picsello.Accounts.User{} = user}} = socket
      ) do
    user = Accounts.clear_user_nylas_code(user)

    {:noreply,
     socket
     |> assign_from_token(user)
     |> assign(%{has_token: false, token: ""})
     |> put_flash(:success, "Calendar disconnected")}
  end

  def handle_event(
        "calendar-read",
        %{"calendar" => cal_id},
        %Socket{assigns: %{read_calendars: read_calendars}} = socket
      ) do
    newset = toggle(read_calendars, cal_id)
    {:noreply, assign(socket, :read_calendars, newset)}
  end

  def handle_event("calendar-read-write", %{"calendar" => cal_id}, socket) do
    Logger.debug("Calendar id \e[0;32m#{cal_id}\e[0;30m")

    {:noreply, assign(socket, :rw_calendar, cal_id)}
  end

  def handle_event(
        "save",
        _,
        %Socket{
          assigns: %{read_calendars: read_calendars, rw_calendar: rw_calendar, current_user: user}
        } = socket
      ) do
    attrs = %{
      external_calendar_rw_id: rw_calendar,
      external_calendar_read_list: MapSet.to_list(read_calendars)
    }

    user = Picsello.Accounts.User.set_nylas_calendars(user, attrs)

    {:noreply,
     assign(socket, :current_user, user) |> put_flash(:success, "Calendar settings saved")}
  end

  defdelegate handle_event(event, params, socket), to: PicselloWeb.Live.Calendar.Shared

  @spec toggle(MapSet.t(String.t()), String.t()) :: MapSet.t(String.t())
  def toggle(calendars, key) do
    if MapSet.member?(calendars, key) do
      MapSet.delete(calendars, key)
    else
      MapSet.put(calendars, key)
    end
  end

  @spec is_member(MapSet.t(), String.t()) :: boolean()
  def is_member(calendars, cal_id) do
    MapSet.member?(calendars, cal_id)

  end

  @spec assign_from_token(Socket.t(), Picsello.Accounts.User.t()) :: Socket.t()
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
