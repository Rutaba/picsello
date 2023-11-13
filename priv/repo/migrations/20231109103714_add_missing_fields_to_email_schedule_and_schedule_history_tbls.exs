defmodule Picsello.Repo.Migrations.AddMissingFieldsToEmailScheduleAndScheduleHistoryTbls do
  use Ecto.Migration

  alias Picsello.{
    EmailAutomation.EmailSchedule,
    EmailAutomationSchedules
  }

  def up do
    alter table(:email_schedules) do
      add(:stopped_reason, :string)
    end

    alter table(:email_schedules_history) do
      add(:stopped_reason, :string)
    end

    flush()
    email_schedules_query = from(es in EmailSchedule, where: not is_nil(es.stopped_at))

    EmailAutomationSchedules.delete_and_insert_schedules_by(
      email_schedules_query,
      :photographer_stopped
    )
  end

  def down do
    alter table(:email_schedules) do
      remove(:stopped_reason)
    end

    alter table(:email_schedules_history) do
      remove(:stopped_reason)
    end
  end
end
