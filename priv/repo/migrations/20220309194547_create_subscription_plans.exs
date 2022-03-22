defmodule Picsello.Repo.Migrations.CreateSubscriptionPlans do
  use Ecto.Migration

  def change do
    create table(:subscription_plans) do
      add :stripe_price_id, :string, null: false
      add :price, :integer, null: false
      add :recurring_interval, :string, null: false

      timestamps()
    end

    create unique_index(:subscription_plans, ~w[stripe_price_id]a)
  end
end
