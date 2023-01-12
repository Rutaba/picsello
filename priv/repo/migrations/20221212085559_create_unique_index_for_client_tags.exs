defmodule Picsello.Repo.Migrations.CreateUniqueIndexForClientTags do
  use Ecto.Migration

  def change do
    create(unique_index(:client_tags, [:name, :client_id]))
  end
end
