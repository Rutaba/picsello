defmodule Picsello.Repo.Migrations.GalleryProducts do
  use Ecto.Migration

  def change do
    alter table(:gallery_products) do
      add(:category_id, references(:categories, on_delete: :nothing), null: false)

      add(:photo_id, references(:photos, on_delete: :nothing), null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

    end

    create index(:gallery_products, [:category_id])
    create index(:gallery_products, [:photo_id])
    create index(:gallery_products, [:gallery_id])
  end
end
