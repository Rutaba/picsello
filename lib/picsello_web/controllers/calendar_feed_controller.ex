defmodule PicselloWeb.CalendarFeedController do
  use PicselloWeb, :controller

  alias Picsello.{Repo, Shoot, Job}
  alias PicselloWeb.Router.Helpers, as: Routes
  import Ecto.Query

  def index(
        %{assigns: %{current_user: current_user}} = conn,
        %{"end" => end_date, "start" => start_date}
      ) do
    data =
      from(shoot in Shoot,
        join: job in assoc(shoot, :job),
        join: client in assoc(job, :client),
        join: status in assoc(job, :job_status),
        where:
          client.organization_id == ^current_user.organization.id and
            is_nil(job.archived_at) and shoot.starts_at >= ^start_date and
            shoot.starts_at <= ^end_date,
        select: {shoot, job, client, status}
      )
      |> Repo.all()
      |> Enum.map(fn {shoot, job, client, status} ->
        {color, url} =
          if status.is_lead do
            {"#86C3CC", Routes.job_path(conn, :leads, job.id)}
          else
            {"#4daac6", Routes.job_path(conn, :jobs, job.id)}
          end

        %{
          title: "#{Job.name(Map.put(job, :client, client))} - #{shoot.name}",
          color: color,
          url: url,
          start:
            shoot.starts_at
            |> DateTime.shift_zone!(current_user.time_zone)
            |> DateTime.to_iso8601(),
          end:
            shoot.starts_at
            |> DateTime.add(shoot.duration_minutes * 60)
            |> DateTime.shift_zone!(current_user.time_zone)
            |> DateTime.to_iso8601()
        }
      end)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(data))
  end
end
