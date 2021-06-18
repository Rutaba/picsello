defmodule Picsello.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:clients, [:organization_id]))
  end
end
