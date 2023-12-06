defmodule Picsello.Repo.Migrations.AddMissingFieldsToEmailScheduleAndScheduleHistoryTbls do
  use Ecto.Migration

  def up do
    alter table(:email_schedules) do
      add(:stopped_reason, :string)
    end

    alter table(:email_schedules_history) do
      add(:stopped_reason, :string)
    end
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
