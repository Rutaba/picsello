defmodule Picsello.Repo.Migrations.AddWatermakedPreviewToPhoto do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      remove(:client_copy_url, :text)
      add(:watermarked_preview_url, :text)
    end
  end
end
