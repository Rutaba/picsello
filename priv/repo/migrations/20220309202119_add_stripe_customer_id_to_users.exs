defmodule Picsello.Repo.Migrations.AddStripeCustomerIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:stripe_customer_id, :text)
    end
  end
end
