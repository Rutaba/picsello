defmodule Picsello.Repo.Migrations.RemoveProductPreviews do
  use Ecto.Migration

  def up do
    drop(table(:product_previews))
  end

  def down do
    create table(:product_previews) do
      add(:index, :integer, default: 1, null: false)
      add(:product_id, references(:products, on_delete: :nothing), null: false)
      add(:photo_id, references(:photos, on_delete: :nothing), null: false)

      timestamps()
    end

    create(index(:product_previews, [:product_id]))
    create(index(:product_previews, [:photo_id]))
  end
end
