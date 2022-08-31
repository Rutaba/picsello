defmodule Picsello.Repo.Migrations.AddStripeIdsToPaymentSchedules do
  use Ecto.Migration

  def change do
    alter table(:payment_schedules) do
      add(:stripe_payment_intent_id, :string)
      add(:stripe_session_id, :string)
    end
  end
end
