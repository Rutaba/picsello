defmodule PicselloWeb.JobLive.Remote do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Phoenix.LiveView.Socket
  alias Picsello.NylasCalendar

  require Logger
  @impl true
  @spec mount(
          map,
          any,
          Socket.t()
        ) :: {:ok, Socket.t()}
  def mount(%{"calendar_id" => _calendar_id, "id" => job_id} = _params, _session, socket) do
    token = socket.assigns.current_user.nylas_oauth_token
    Logger.info("TOKEN #{token}")
    time_zone = socket.assigns.current_user.time_zone
    {:ok, event} = NylasCalendar.get_event_details(job_id, token)
    socket |> assign(event) |> assign(:time_zone, time_zone) |> ok()
  end

  def convert_time(time, time_zone) do
    time |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%I:%M:%S %p %B %-d, %Y")
  end
end
