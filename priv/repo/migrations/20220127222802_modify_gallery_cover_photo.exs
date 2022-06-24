defmodule Picsello.Repo.Migrations.ModifyGalleryCoverPhoto do
  use Ecto.Migration

  def change do
    alter table("galleries") do
      remove(:cover_photo_id, :string)
      remove(:cover_photo_aspect_ratio, :float)
      add(:cover_photo, :map)
    end
  end
end
