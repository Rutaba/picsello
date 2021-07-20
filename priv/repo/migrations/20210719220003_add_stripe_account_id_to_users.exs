defmodule Picsello.Repo.Migrations.AddStripeAccountIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:stripe_account_id, :text)
    end
  end
end
