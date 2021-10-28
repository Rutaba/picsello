defmodule Picsello.Repo.Migrations.AddCoverPhotoToGallery do
  use Ecto.Migration

  def up do
    alter table(:galleries) do
      add(:cover_photo_url, :text)
      add(:cover_photo_aspect_ratio, :float)
      remove(:cover_photo_id) 
    end
  end

  def down do
    alter table(:galleries) do
      remove(:cover_photo_url)
      remove(:cover_photo_aspect_ratio)
      add(:cover_photo_id, :integer)
    end
  end
end
