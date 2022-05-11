defmodule Picsello.Repo.Migrations.AddThumbnailUrlToAlbum do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add(:thumbnail_url, :string)
    end
  end
end
