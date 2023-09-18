defmodule PicselloWeb.CalendarFeedController do
  use PicselloWeb, :controller

  alias Picsello.{Shoots, Job, NylasCalendar, Utils}
  require Logger
  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(%{assigns: %{current_user: %{nylas_detail: nylas_detail} = user}} = conn, params) do
    %{"end" => end_date, "start" => start_date} = params
    feeds = user |> Shoots.get_shoots(params) |> map(conn, user)

    events =
      nylas_detail
      |> Map.get(:external_calendar_read_list)
      |> NylasCalendar.get_external_events(
        nylas_detail.oauth_token,
        {Utils.to_unix(start_date), Utils.to_unix(end_date)},
        user.time_zone
      )

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(feeds ++ events))
  end

  defp map(feeds, conn, user) do
    feeds
    |> Enum.map(fn {shoot, job, client, status} ->
      {color, type} = if(status.is_lead, do: {"#86C3CC", :leads}, else: {"#4daac6", :jobs})

      start_date =
        shoot.starts_at
        |> DateTime.shift_zone!(user.time_zone)
        |> DateTime.to_iso8601()

      end_date =
        shoot.starts_at
        |> DateTime.add(shoot.duration_minutes * 60)
        |> DateTime.shift_zone!(user.time_zone)
        |> DateTime.to_iso8601()

      %{
        title: "#{Job.name(Map.put(job, :client, client))} - #{shoot.name}",
        color: color,
        other: %{
          url: Routes.job_path(conn, type, job.id, %{"request_from" => "calendar"}),
          job_id: job.id,
          calendar: "internal"
        },
        start: start_date,
        end: end_date
      }
    end)
  end
end
