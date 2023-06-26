defmodule Picsello.Repo.Migrations.CreateTableEmailAutomationSlug do
  use Ecto.Migration

  @table "email_automation_sub_categories"
  def up do
    create table(@table) do
      add(:name, :string, null: false)
      add(:slug, :string, null: false)

      timestamps()
    end

    create(unique_index(@table, [:slug, :name]))
  end

  def down do
    drop(table(@table))
  end
end
