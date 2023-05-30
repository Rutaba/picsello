defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationPipelines do
  use Ecto.Migration

  @table "email_automation_pipelines"
  def up do
    execute("CREATE TYPE email_automation_pipeline_status AS ENUM ('active','disabled','archived')")

    create table(@table) do
      add(:name, :string, null: false)
      add(:status, :email_automation_pipeline_status, null: false)
      add(:state, :string, null: false)
      add(:email_automation_id, references(:email_automations, on_delete: :nothing))
      add(:organization_id, references(:organizations, on_delete: :nothing))
   
      timestamps()
    end

    create(unique_index(@table, [:name, :state]))
  end

  def down do
    drop(table(@table))
  end
end


from email_auto_pipelines
join email_auto
join 3rd
where org_id: 1
group by email_auto, 3rd