defmodule Picsello.Repo.Migrations.AddAlbumIdToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add(:album_id, references(:albums, on_delete: :nothing))
    end

    create(index(:photos, [:album_id]))
  end
end
