defmodule Picsello.Repo.Migrations.CreateAlbumsTable do
  use Ecto.Migration

  def change do
    create table(:albums) do
      add(:name, :string, null: false)
      add(:password, :string)
      add(:set_password, :boolean)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:albums, [:gallery_id])
  end
end
