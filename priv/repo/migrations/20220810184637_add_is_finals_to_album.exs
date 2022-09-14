defmodule Picsello.Repo.Migrations.AddIsFinalsToAlbum do
  use Ecto.Migration

  def change do
    alter table(:albums) do
      add(:is_finals, :boolean, null: false, default: false)
    end
  end
end
