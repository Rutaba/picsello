defmodule Picsello.Repo.Migrations.CreateQuestionnaires do
  use Ecto.Migration

  def up do
    create table(:job_types, primary_key: false) do
      add(:name, :string, primary_key: true)
    end

    execute("""
      insert into job_types (name)
      values ('wedding'), ('family'), ('newborn'), ('other')
    """)

    alter table(:jobs) do
      modify(:type, references(:job_types, column: :name, type: :string))
    end

    create table(:questionnaires) do
      add(:questions, :map, null: false)
      add(:job_type, references(:job_types, column: :name, type: :string), null: false)

      timestamps()
    end
  end

  def down do
    alter table(:jobs) do
      modify(:type, :string, from: references(:job_types, column: :name, type: :string))
    end

    drop(table(:questionnaires))

    drop(table(:job_types))
  end
end
