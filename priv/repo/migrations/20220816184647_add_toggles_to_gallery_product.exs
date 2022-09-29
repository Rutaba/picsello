defmodule Picsello.Repo.Migrations.AddTogglesToGalleryProduct do
  use Ecto.Migration

  def up do
    alter table(:gallery_products) do
      add(:sell_product_enabled, :boolean, null: false, default: true)
      add(:product_preview_enabled, :boolean, null: false, default: true)
    end
  end

  def down do
    alter table(:gallery_products) do
      remove(:sell_product_enabled, :boolean)
      remove(:product_preview_enabled, :boolean)
    end
  end
end