defmodule Picsello.Repo.Migrations.GalleriesCovers do
  use Ecto.Migration

  def change do
    create table(:galleries_covers) do
      add(:category_template_id, references(:category_templates, on_delete: :nothing), null: false)
      add(:photo_id, references(:photos, on_delete: :nothing), null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:galleries_covers, [:category_template_id])
    create index(:galleries_covers, [:photo_id])
    create index(:galleries_covers, [:gallery_id])
  end
end
