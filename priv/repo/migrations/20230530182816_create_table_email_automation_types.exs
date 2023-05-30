defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationTypes do
  use Ecto.Migration

  @table "email_automation_types"
  def up do
    create table(@table) do
      add(
        :email_automation_setting_id,
        references(:email_automation_settings, on_delete: :nothing)
      )

      add(:email_preset_id, references(:email_presets, on_delete: :nothing))
      add(:organization_job_id, references(:organization_job_types, on_delete: :nothing))

      timestamps()
    end
  end

  def down do
    drop(table(@table))
  end
end
