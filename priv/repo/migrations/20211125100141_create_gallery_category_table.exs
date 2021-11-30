defmodule Picsello.Repo.Migrations.GalleryCategory do
  use Ecto.Migration

  def change do
    create table(:gallery_category) do
      add(:category_template_id, references(:category_templates, on_delete: :nothing), null: false)
      add(:photo_id, references(:photos, on_delete: :nothing), null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:gallery_category, [:category_template_id])
    create index(:gallery_category, [:photo_id])
    create index(:gallery_category, [:gallery_id])
  end
end
