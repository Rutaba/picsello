defmodule Picsello.Repo.Migrations.CreateClientTags do
  use Ecto.Migration

  @table :client_tags
  def change do
    create table(@table) do
      add(:client_id, references("clients"), null: false)
      add(:name, :string, null: false)

      timestamps(type: :utc_datetime)
    end
  end
end
