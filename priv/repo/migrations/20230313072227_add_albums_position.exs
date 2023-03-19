defmodule Picsello.Repo.Migrations.AddAlbumsPosition do
  use Ecto.Migration

  def up do
    alter table(:albums) do
      add(:position, :float, null: false, default: 0)
    end
  end

  def down do
    alter table(:albums) do
      remove(:position)
    end
  end
end
