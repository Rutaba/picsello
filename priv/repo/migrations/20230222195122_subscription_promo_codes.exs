defmodule Picsello.Repo.Migrations.SubscriptionPromoCodes do
  use Ecto.Migration

  def change do
    create table(:subscription_promotion_codes) do
      add(:code, :string, null: false)
      add(:stripe_promotion_code_id, :string, null: false)
      add(:percent_off, :decimal, null: false)

      timestamps()
    end

    create(unique_index(:subscription_promotion_codes, ~w[stripe_promotion_code_id]a))
  end
end
