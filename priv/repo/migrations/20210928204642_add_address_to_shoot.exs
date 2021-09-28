defmodule Picsello.Repo.Migrations.AddAddressToShoot do
  use Ecto.Migration

  def change do
    alter table(:shoots) do
      add(:address, :text)
    end
  end
end
