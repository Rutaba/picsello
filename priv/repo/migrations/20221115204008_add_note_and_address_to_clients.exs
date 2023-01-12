defmodule Picsello.Repo.Migrations.AddNoteAndAddressToClients do
  use Ecto.Migration

  def up do
    alter table(:clients) do
      add_if_not_exists(:note, :string, default: nil)
      add_if_not_exists(:address, :string, default: nil)
    end
  end

  def down do
    alter table(:clients) do
      remove(:note, :string)
      remove(:address, :string)
    end
  end
end
