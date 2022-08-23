defmodule Picsello.Repo.Migrations.AddClientLinkHashTTOAlbum do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add(:client_link_hash, :string)
    end
  end
end
