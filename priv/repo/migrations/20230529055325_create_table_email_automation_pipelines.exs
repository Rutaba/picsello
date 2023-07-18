defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationPipelines do
  use Ecto.Migration

  @table "email_automation_pipelines"
  def up do
    create table(@table) do
      add(:name, :string, null: false)
      add(:state, :string, null: false)
      add(:description, :text, null: false)

      add(
        :email_automation_sub_category_id,
        references(:email_automation_sub_categories, on_delete: :nothing)
      )

      add(
        :email_automation_category_id,
        references(:email_automation_categories, on_delete: :nothing)
      )

      timestamps()
    end

    create(unique_index(@table, [:name, :state]))

    if System.get_env("MIX_ENV") != "prod" do
      flush()
      Mix.Tasks.ImportEmailAutomationPipelines.insert_email_pipelines()
    end
  end

  def down do
    drop(table(@table))
  end
end
