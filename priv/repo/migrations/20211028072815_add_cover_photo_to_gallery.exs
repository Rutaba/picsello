defmodule Picsello.Repo.Migrations.AddCoverPhotoToGallery do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      modify(:cover_photo_id, :string)
      add(:cover_photo_aspect_ratio, :float)
    end
  end
end
