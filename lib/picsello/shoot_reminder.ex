defmodule Picsello.ShootReminder do
  @moduledoc false
  alias Picsello.{
    Repo,
    Shoot,
    EmailPresets,
    Messages,
    Notifiers.ClientNotifier
  }

  import Ecto.Query

  def deliver_all(helpers) do
    pending_shoots()
    |> Enum.each(fn shoot ->
      send_reminder_message(shoot, :shoot_reminder, &Shoot.reminded_at_changeset/1, helpers)
    end)

    recent_completed_shoots()
    |> Enum.each(fn shoot ->
      send_reminder_message(shoot, :shoot_thanks, &Shoot.thanked_at_changeset/1, helpers)
    end)

    :ok
  end

  defp pending_shoots() do
    from(shoot in job_shoots_query(),
      where:
        is_nil(shoot.reminded_at) and
          fragment(
            "?.starts_at between (now() at time zone 'utc') and (now() at time zone 'utc') + interval '1 day'",
            shoot
          )
    )
    |> Repo.all()
  end

  defp recent_completed_shoots() do
    from(shoot in job_shoots_query(),
      where:
        is_nil(shoot.thanked_at) and
          fragment(
            "?.starts_at between (now() at time zone 'utc') - interval '2 day' and (now() at time zone 'utc') - interval '1 day'",
            shoot
          )
    )
    |> Repo.all()
  end

  defp job_shoots_query() do
    from(shoot in Shoot,
      join: job in assoc(shoot, :job),
      join: status in assoc(job, :job_status),
      where: status.is_lead == false
    )
  end

  defp send_reminder_message(shoot, preset_state, shoot_update_changeset, helpers) do
    with job <- shoot |> Repo.preload(job: :client) |> Map.get(:job),
         [preset | _] <- EmailPresets.for(job, preset_state),
         %{body_template: body, subject_template: subject} <-
           EmailPresets.resolve_variables(preset, {job}, helpers) do
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :message,
        Messages.scheduled_message_changeset(
          %{subject: subject, body_text: HtmlSanitizeEx.strip_tags(body), body_html: body},
          job
        )
      )
      |> Ecto.Multi.update(:shoot_update, shoot_update_changeset.(shoot))
      |> Ecto.Multi.run(
        :email,
        fn _, changes ->
          ClientNotifier.deliver_email(changes.message, job.client.email)

          {:ok, :email}
        end
      )
      |> Repo.transaction()
    end
  end
end
