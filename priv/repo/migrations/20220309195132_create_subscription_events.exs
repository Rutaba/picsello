defmodule Picsello.Repo.Migrations.CreateSubscriptionEvents do
  use Ecto.Migration

  def change do
    create table(:subscription_events) do
      add :status, :string, null: false
      add :stripe_subscription_id, :string, null: false
      add :current_period_start, :utc_datetime, null: false
      add :current_period_end, :utc_datetime, null: false
      add :cancel_at, :utc_datetime
      add :subscription_type_id, references(:subscription_types, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:subscription_events, [:subscription_type_id])
    create index(:subscription_events, [:user_id])
  end
end
