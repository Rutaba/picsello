defmodule Picsello.Repo.Migrations.CreatePreferredFilters do
  use Ecto.Migration

  def change do
    create table(:preferred_filters) do
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
      add(:type, :string)
      add(:filters, :map, null: false, default: %{})

      timestamps()
    end

    create(index(:preferred_filters, [:organization_id]))
  end
end
