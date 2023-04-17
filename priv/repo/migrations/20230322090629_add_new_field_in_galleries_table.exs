defmodule Picsello.Repo.Migrations.AddNewFieldInGalleriesTable do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:gallery_analytics, {:array, :map})
    end
  end
end
