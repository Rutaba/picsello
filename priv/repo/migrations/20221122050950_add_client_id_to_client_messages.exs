defmodule Picsello.Repo.Migrations.AddClientIdToClientMessages do
  use Ecto.Migration

  def up do
    alter table(:client_messages) do
      modify(:job_id, :bigint, null: true)
      add(:client_id, references(:clients))
    end

    execute("""
     update client_messages set client_id = jobs.client_id from jobs
     where jobs.id = job_id;
    """)

    create(index(:client_messages, [:client_id]))
  end

  def down do
    alter table(:client_messages) do
      modify(:job_id, :bigint, null: false)
      remove(:client_id, references(:clients))
    end

    drop(index(:client_messages, [:client_id]))
  end
end
