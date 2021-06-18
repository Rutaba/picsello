defmodule Picsello.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add(:type, :string, null: false)
      add(:client_id, references(:clients, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:jobs, [:client_id]))
  end
end
