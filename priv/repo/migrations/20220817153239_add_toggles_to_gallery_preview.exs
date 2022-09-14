defmodule Picsello.Repo.Migrations.AddTogglesToGalleryPreview do
  use Ecto.Migration

  def change do
    execute(
      "alter table gallery_products add column preview_enabled boolean not null default true",
      "alter table gallery_products drop column preview_enabled"
    )
  end
end
