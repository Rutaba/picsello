defmodule Picsello.Repo.Migrations.AlterTableEmailPresets do
  use Ecto.Migration

  @table "email_presets"
  def up do
    execute("CREATE TYPE email_preset_status AS ENUM ('active','disabled')")
    
    alter table(@table) do
      add(:status, :email_preset_status, null: true)
      add(:total_hours, :integer)
      add(:condition, :string)
      add(:private_name, :string)

      add(
        :email_automation_pipeline_id,
        references(:email_automation_pipelines, on_delete: :nothing)
      )
      add(:organization_id, references(:organizations, on_delete: :nothing))
    end
    
    flush()
    Mix.Tasks.ImportEmailPresets.insert_emails()

    execute("""
      update #{@table} set status='active' where organization_id is NULL;
    """)
  end
  def down do
    execute("""
    alter table email_presets drop column status, drop column total_hours, drop column condition, drop column private_name, drop column email_automation_pipeline_id, drop column organization_id
  """)
  execute("DROP TYPE email_preset_status")
  end
end
