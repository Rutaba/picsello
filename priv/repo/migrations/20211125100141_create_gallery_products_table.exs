defmodule Picsello.Repo.Migrations.GalleryProducts do
  use Ecto.Migration

  def up do
    drop_if_exists table(:gallery_products), mode: :cascade
    create table(:gallery_products) do
      add :name, :string
      add :price, :integer
      add(:category_id, references(:category_templates, on_delete: :nothing), null: false)

      add(:preview_photo_id, references(:photos, on_delete: :nothing), null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:gallery_products, [:category_id])
    create index(:gallery_products, [:preview_photo_id])
    create index(:gallery_products, [:gallery_id])
  end

  def down do
    drop_if_exists table(:gallery_products), mode: :cascade
  end
end
