defmodule Picsello.Repo.Migrations.AddGalleriesClients do
  use Ecto.Migration

  @table "gallery_clients"
  def up do
    create table(@table) do
      add(:email, :string, null: false)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end
  end

  def down do
    drop(table(@table))
  end
end
