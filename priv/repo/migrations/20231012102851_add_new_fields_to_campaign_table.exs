defmodule Picsello.Repo.Migrations.AddNewFieldsToCampaignTable do
  use Ecto.Migration

  def change do
    alter table(:campaigns) do
      add(:read_at, :utc_datetime)
      add(:deleted_at, :utc_datetime)
    end
  end
end
