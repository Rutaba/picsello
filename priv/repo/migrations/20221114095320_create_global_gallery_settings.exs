defmodule Picsello.Repo.Migrations.CreateGlobalGallerySettings do
  use Ecto.Migration

  def change do
    create table(:global_gallery_settings) do
      add(:expiration_days, :integer)
      add(:organization_id, references(:organizations, on_delete: :nothing), null: false)
      timestamps()
    end

    create(index(:global_gallery_settings, [:organization_id]))
  end
end
