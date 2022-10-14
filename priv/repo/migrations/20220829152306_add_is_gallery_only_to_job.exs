defmodule Picsello.Repo.Migrations.AddIsGalleryOnlyToJob do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:is_gallery_only, :boolean, default: false)
    end
  end
end
