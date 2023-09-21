defmodule PicselloWeb.CalendarFeedController do
  use PicselloWeb, :controller

  alias Picsello.{Shoots, Job, BookingEvents}

  def index(%{assigns: %{current_user: user}} = conn, params) do
    feeds = Shoots.get_shoots(user, params) |> map(conn, user)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(feeds))
  end

  def show(%{assigns: %{current_user: user}} = conn, %{"id" => event_id} = params) do
    IO.inspect(params, label: "Event ID --------->")
    booking_event = BookingEvents.get_preloaded_booking_event!(user.organization_id, event_id) |> Map.get(:dates) |> map_event() |> IO.inspect(label: "Booking Event --------------->")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(booking_event))
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
        url: Routes.job_path(conn, type, job.id, %{"request_from" => "calendar"}),
        start: start_date,
        end: end_date
      }
    end)
  end


  defp map_event(dates) do
    if Enum.empty?(dates) do
      %{}
    else
      start_date =
        dates
        |> List.first()
        |> Map.get(:date)
        |> Date.to_iso8601()

      end_date =
        dates
        |> List.last()
        |> Map.get(:date)
        |> Date.to_iso8601()

      %{
        start: start_date,
        end: end_date
      }
    end
  end
end
