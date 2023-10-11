defmodule Picsello.Repo.Migrations.RemoveFieldsFromAlbums do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      remove(:set_password)
      remove(:password)
    end
  end
end
