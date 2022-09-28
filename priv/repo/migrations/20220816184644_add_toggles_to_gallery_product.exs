defmodule Picsello.Repo.Migrations.AddTogglesToGalleryProduct do
  use Ecto.Migration

  def change do
    execute(
      "alter table gallery_products add column sell_product_enabled boolean not null default true",
      "alter table gallery_products drop column sell_product_enabled"
    )
    execute(
      "alter table gallery_products add column product_preview_enabled boolean not null default true",
      "alter table gallery_products drop column product_preview_enabled"
    )
  end
end
