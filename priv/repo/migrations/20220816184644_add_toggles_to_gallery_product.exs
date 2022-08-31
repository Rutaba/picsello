defmodule Picsello.Repo.Migrations.AddTogglesToGalleryProduct do
  use Ecto.Migration

  def change do
    execute(
      "alter table gallery_products add column enabled boolean not null default true",
      "alter table gallery_products drop column enabled"
    )
  end
end
