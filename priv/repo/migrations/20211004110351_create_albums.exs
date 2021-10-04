defmodule Picsello.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums) do
      add :name, :string
      add :position, :float
      add :gallery_id, references(:galleries, on_delete: :nothing)

      timestamps()
    end

    create index(:albums, [:gallery_id])
  end
end
