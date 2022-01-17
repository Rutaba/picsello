defmodule Picsello.Repo.Migrations.RemoveAlbums do
  use Ecto.Migration

  def up do
    alter table("photos") do
      remove :album_id
    end

    drop table("albums")
  end

  def down do
    create table(:albums) do
      add(:name, :string, null: false)
      add(:position, :float, null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:albums, [:gallery_id])

    alter table("photos") do
      add :album_id, references(:albums)
    end
  end
end
