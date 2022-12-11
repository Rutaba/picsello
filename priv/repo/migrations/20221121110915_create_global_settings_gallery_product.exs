defmodule Picsello.Repo.Migrations.CreateGlobalSettingsGalleryProduct do
  use Ecto.Migration

  def change do
    create table(:global_settings_gallery_products) do
      add(:sell_product_enabled, :boolean)
      add(:product_preview_enabled, :boolean)
      add(:markup, :decimal)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
      add(:category_id, references(:categories, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:global_settings_gallery_products, [:organization_id]))
    create(unique_index(:global_settings_gallery_products, [:organization_id, :category_id]))
  end
end
