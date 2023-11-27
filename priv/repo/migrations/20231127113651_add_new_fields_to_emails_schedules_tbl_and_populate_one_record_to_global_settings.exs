defmodule Picsello.Repo.Migrations.AddNewFieldsToEmailsSchedulesTblAndPopulateOneRecordToGlobalSettings do
  use Ecto.Migration

  alias Picsello.{AdminGlobalSetting, Repo}
  import Ecto.Query

  def up do
    populate_automation_setting_to_admin_global_settings()

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

  defp populate_automation_setting_to_admin_global_settings(),
    do:
      Repo.insert(
        AdminGlobalSetting.changeset(%AdminGlobalSetting{}, %{
          title: "Automation Setting",
          slug: "approval_required",
          description: "Global Settings for the email-automation feature",
          value: "false",
          status: :active
        })
      )

  defp remove_automation_setting_from_admin_global_settings(),
    do:
      Repo.delete(
        from(ags in AdminGlobalSetting, where: ags.slug == "approval_required")
        |> Repo.one()
      )
end
