defmodule Picsello.Repo.Migrations.RemoveAlbums do
  use Ecto.Migration

  def change do
    alter table("photos") do
      remove :album_id
    end

    drop table("albums")
  end
end
