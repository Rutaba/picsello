defmodule Picsello.Repo.Migrations.AddNewFieldsToEmailsSchedulesTblAndPopulateOneRecordToGlobalSettings do
  use Ecto.Migration

  alias Picsello.{AdminGlobalSetting, Repo}
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
