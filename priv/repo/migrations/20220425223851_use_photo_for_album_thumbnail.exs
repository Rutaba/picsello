defmodule Picsello.Repo.Migrations.UsePhotoForAlbumThumbnail do
  use Ecto.Migration

  def up do
    execute("""
      alter table albums add column thumbnail_photo_id integer references photos, drop column thumbnail_url
    """)
  end

  def down do
    execute("""
      alter table albums drop column thumbnail_photo_id, add column thumbnail_url text
    """)
  end
end
