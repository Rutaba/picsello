defmodule Picsello.Repo.Migrations.AddGlobalWatermarkPathToGlobalGallerySettings do
  use Ecto.Migration
  def change do
    alter table(:global_gallery_settings) do
      add(:global_watermark_path, :string)
    end
  end
end
