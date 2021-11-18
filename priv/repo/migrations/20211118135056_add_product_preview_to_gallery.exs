defmodule Picsello.Repo.Migrations.AddProductPreviewToGallery do
  use Ecto.Migration

  def change do
    alter table("galleries") do
      add :product_preview, :text
    end
  end
end
