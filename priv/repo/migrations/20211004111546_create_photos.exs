defmodule Picsello.Repo.Migrations.CreatePhotos do
  use Ecto.Migration

  def change do
    create table(:photos) do
      add(:name, :string, null: false)
      add(:position, :float, null: false)
      add(:original_url, :string, null: false)
      add(:preview_url, :string)
      add(:watermarked_url, :string)
      add(:client_copy_url, :string)
      add(:client_liked, :boolean, default: false, null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)
      add(:album_id, references(:albums, on_delete: :nothing))

      timestamps()
    end

    create index(:photos, [:gallery_id])
    create index(:photos, [:album_id])
  end
end
