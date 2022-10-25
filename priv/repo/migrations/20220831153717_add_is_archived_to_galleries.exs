defmodule Picsello.Repo.Migrations.AddIsArchivedToGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add(:disabled, :boolean, default: false, null: false)
    end
  end
end
