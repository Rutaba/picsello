defmodule PicselloWeb.CalendarFeedController do
  use PicselloWeb, :controller

  alias Picsello.{Shoots, Job}

  def index(%{assigns: %{current_user: user}} = conn, params) do
    feeds = Shoots.get_shoots(user, params) |> map(conn, user)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(feeds))
  end

  defp map(feeds, conn, user) do
    feeds
    |> Enum.map(fn {shoot, job, client, status} ->
      {color, url} =
        if status.is_lead do
          {"#86C3CC", Routes.job_path(conn, :leads, job.id)}
        else
          {"#4daac6", Routes.job_path(conn, :jobs, job.id)}
        end

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
        url: url,
        start: start_date,
        end: end_date
      }
    end)
  end
end
