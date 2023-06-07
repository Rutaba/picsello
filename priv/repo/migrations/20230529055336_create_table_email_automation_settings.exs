defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationSettings do
  use Ecto.Migration

  @table "email_automation_settings"
  def up do
    execute("CREATE TYPE email_automation_setting_status AS ENUM ('active','disabled')")

    create table(@table) do
      add(:status, :email_automation_setting_status, null: false)
      add(:total_hours, :integer)
      add(:condition, :string)

      add(
        :email_automation_pipeline_id,
        references(:email_automation_pipelines, on_delete: :nothing)
      )

      add(:organization_id, references(:organizations, on_delete: :nothing))

      timestamps()
    end
  end

  def down do
    drop(table(@table))
  end
end
