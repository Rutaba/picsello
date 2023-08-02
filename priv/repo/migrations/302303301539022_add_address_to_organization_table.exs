defmodule Picsello.Repo.Migrations.AddAddressToOrganizationTable do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add(:address, :map)
    end
  end
end
