defmodule Picsello.Repo.Migrations.AddStripeCustomerIdToClients do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      add(:stripe_customer_id, :text)
    end
  end
end
