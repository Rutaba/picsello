defmodule Picsello.Repo.Migrations.AddAlbumIdToOrder do
  use Ecto.Migration

  def change do
    alter table(:gallery_orders) do
      add(:album_id, references(:albums, on_delete: :nothing))
    end
  end
end
