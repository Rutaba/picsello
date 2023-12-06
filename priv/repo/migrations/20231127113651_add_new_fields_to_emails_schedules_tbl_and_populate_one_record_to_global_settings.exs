defmodule Picsello.Repo.Migrations.AddNewFieldsToEmailsSchedulesTblAndPopulateOneRecordToGlobalSettings do
  use Ecto.Migration

  alias Picsello.{
    Repo,
    AdminGlobalSetting,
    EmailAutomation.EmailSchedule,
    EmailAutomationSchedules
  }

  import Ecto.Query

  def up do
    execute("""
      INSERT INTO admin_global_settings VALUES (#{7}, 'Automation Setting', 'Global Settings for the email-automation feature', 'approval_required', 'false', 'active', now(), now());
    """)

    alter table(:email_schedules) do
      add(:approval_required, :boolean, default: false)
    end

    alter table(:email_schedules_history) do
      add(:approval_required, :boolean, default: false)
    end

    flush()
    email_schedules_query = from(es in EmailSchedule, where: not is_nil(es.stopped_at))

    EmailAutomationSchedules.delete_and_insert_schedules_by_multi(
      email_schedules_query,
      :photographer_stopped
    )
    |> Repo.transaction()
  end

  def down do
    remove_automation_setting_from_admin_global_settings()

    alter table(:email_schedules) do
      remove(:approval_required)
    end

    alter table(:email_schedules_history) do
      remove(:approval_required)
    end
  end

  defp remove_automation_setting_from_admin_global_settings(),
    do:
      Repo.delete(
        from(ags in AdminGlobalSetting, where: ags.slug == "approval_required")
        |> Repo.one()
      )
end
