defmodule Picsello.Repo.Migrations.AddReferalFieldsToClients do
  use Ecto.Migration

  def up do
    alter table(:clients) do
      add(:referred_by, :string)
      add(:referral_name, :string)
    end
  end

  def down do
    alter table(:clients) do
      remove(:referred_by)
      remove(:referral_name)
    end
  end
end
