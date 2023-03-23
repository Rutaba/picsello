defmodule PicselloWeb.ICalendarController do
  use PicselloWeb, :controller

  alias Picsello.{Accounts, Shoots, Repo, Job}

  import PicselloWeb.Helpers, only: [job_url: 1, lead_url: 1]

  def index(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, "USER_ID", token, max_age: :infinity) do
      {:ok, user_id} ->
        user = Accounts.get_user!(user_id) |> Repo.preload(:organization)

        params = %{
          "start" => DateTime.utc_now(),
          "end" => DateTime.utc_now() |> DateTime.add(2 * 365 * 24 * 60 * 60)
        }

        events = Shoots.get_shoots(user, params) |> map(user)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, %ICalendar{events: events} |> ICalendar.to_ics())

      {:error, _} ->
        conn
        |> put_flash(:error, "Unauthorized")
        |> redirect(to: "/")
    end
  end

  defp map(feeds, user) do
    feeds
    |> Enum.map(fn {shoot, job, client, status} ->
      url = if status.is_lead, do: job_url(job.id), else: lead_url(job.id)

      start_date =
        shoot.starts_at
        |> DateTime.shift_zone!(user.time_zone)

      end_date =
        shoot.starts_at
        |> DateTime.add(shoot.duration_minutes * 60)
        |> DateTime.shift_zone!(user.time_zone)

      title = "#{Job.name(Map.put(job, :client, client))} - #{shoot.name}"

      %ICalendar.Event{
        summary: title,
        dtstart: start_date,
        dtend: end_date,
        description: shoot.notes,
        organizer: user.email,
        uid: "shoot_#{shoot.id}@picsello.com",
        attendees: [
          %{
            "PARTSTAT" => "ACCEPTED",
            "CN" => user.email,
            original_value: "mailto:#{user.email}"
          }
        ],
        url: url,
        location: shoot.address || shoot.location |> Atom.to_string() |> dyn_gettext()
      }
    end)
  end
end
