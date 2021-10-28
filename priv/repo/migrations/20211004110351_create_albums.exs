defmodule Picsello.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums) do
      add(:name, :string, null: false)
      add(:position, :float, null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:albums, [:gallery_id])
  end
end
