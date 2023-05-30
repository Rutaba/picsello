defmodule Picsello.Repo.Migrations.CreateTableEmailAutomations do
  use Ecto.Migration

  @table "email_automations"
  def up do
    execute("CREATE TYPE email_automation_type AS ENUM ('lead','job','gallery','general')")

    create table(@table) do
      add(:name, :string, null: false)
      add(:type, :email_automation_type, null: false)
   
      timestamps()
    end
    
    create(unique_index(@table, [:type, :name]))
  end

  def down do
    drop(table(@table))
  end
end
