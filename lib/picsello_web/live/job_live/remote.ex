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
  def mount(%{"id" => event_id}, _session, %{assigns: %{current_user: user}} = socket) do
    token = user.nylas_detail.oauth_token

    Logger.info("TOKEN #{token}")
    time_zone = user.time_zone
    {:ok, event} = NylasCalendar.get_event_details(event_id, token)

    socket
    |> assign(event)
    |> assign(:time_zone, time_zone)
    |> ok()
  end

  def convert_time(time, time_zone) do
    time
    |> DateTime.shift_zone!(time_zone)
    |> Calendar.strftime("%I:%M:%S %p %B %-d, %Y")
  end
end
