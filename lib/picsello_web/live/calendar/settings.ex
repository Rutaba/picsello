defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{NylasCalendar, NylasDetails}
  alias PicselloWeb.Endpoint
  alias Phoenix.{LiveView.Socket, PubSub}

  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  require Logger

  @impl true

  @spec mount(
          map(),
          map(),
          Phoenix.LiveView.Socket.t()
        ) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(
        _params,
        _session,
        %{assigns: %{current_user: %{nylas_detail: nylas_detail} = user}} = socket
      ) do
    url = Routes.i_calendar_url(socket, :index, Phoenix.Token.sign(Endpoint, "USER_ID", user.id))
    {:ok, nylas_url} = NylasCalendar.generate_login_link()

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "move_events:#{nylas_detail.id}")
    end

    socket
    |> assign(%{
      url: url,
      error: false,
      calendars: [],
      has_token: false,
      token: "",
      nylas_detail: nylas_detail,
      nylas_url: nylas_url,
      rw_calendar: nylas_detail.external_calendar_rw_id,
      read_calendars: to_set(nylas_detail)
    })
    |> disable_settings_buttons?(nylas_detail)
    |> assign_from_token()
    |> ok()
  end

  defp disable_settings_buttons?(socket, %{
         event_status: event_status,
         external_calendar_rw_id: id
       }) do
    assign(
      socket,
      :disable_settings_buttons?,
      event_status in [:in_progress, :initial] && is_binary(id)
    )
  end

  defp to_set(%{external_calendar_read_list: nil}), do: MapSet.new([])
  defp to_set(%{external_calendar_read_list: list}), do: MapSet.new(list)

  @impl true
  @spec handle_event(String.t(), any, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event(
        "disconnect_calendar",
        _,
        %Socket{assigns: %{nylas_detail: nylas_detail}} = socket
      ) do
    nylas_detail = NylasDetails.clear_nylas_token!(nylas_detail)

    {:noreply,
     socket
     |> assign(:nylas_detail, nylas_detail)
     |> assign_from_token()
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
          assigns: %{
            read_calendars: read_calendars,
            rw_calendar: rw_calendar,
            nylas_detail: nylas_detail
          }
        } = socket
      ) do
    nylas_detail =
      NylasDetails.set_nylas_calendars!(nylas_detail, %{
        external_calendar_rw_id: rw_calendar,
        external_calendar_read_list: MapSet.to_list(read_calendars)
      })

    socket
    |> assign(:nylas_detail, nylas_detail)
    |> disable_settings_buttons?(nylas_detail)
    |> put_flash(:success, "Calendar settings saved")
    |> noreply
  end

  defdelegate handle_event(event, params, socket), to: PicselloWeb.Live.Calendar.Shared

  def handle_info(
        {:move_events, nylas_detail},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    current_user
    |> Map.put(:nylas_detail, nylas_detail)
    |> then(&assign(socket, :current_user, &1))
    |> disable_settings_buttons?(nylas_detail)
    |> noreply()
  end

  defp toggle(calendars, key) do
    if MapSet.member?(calendars, key) do
      MapSet.delete(calendars, key)
    else
      MapSet.put(calendars, key)
    end
  end

  defp is_member(calendars, cal_id), do: MapSet.member?(calendars, cal_id)

  defp assign_from_token(%{assigns: %{nylas_detail: %{oauth_token: token}}} = socket)
       when is_binary(token) do
    case NylasCalendar.get_calendars(token) do
      {:ok, calendars} ->
        assign(socket, %{has_token: true, token: token, calendars: calendars})

      {:error, msg} ->
        assign(socket, %{error: msg})
    end
  end

  defp assign_from_token(socket), do: socket
end
