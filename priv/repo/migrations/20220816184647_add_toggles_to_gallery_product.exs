defmodule Picsello.Repo.Migrations.AddTogglesToGalleryProduct do
  use Ecto.Migration

  def up do
    alter table(:gallery_products) do
      add_if_not_exists(:sell_product_enabled, :boolean, null: false, default: true)
      add_if_not_exists(:product_preview_enabled, :boolean, null: false, default: true)
    end
  end

  def down do
    alter table(:gallery_products) do
      remove(:sell_product_enabled, :boolean)
      remove(:product_preview_enabled, :boolean)
    end
  end
end
