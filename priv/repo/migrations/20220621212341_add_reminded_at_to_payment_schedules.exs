defmodule Picsello.Repo.Migrations.AddRemindedAtToPaymentSchedules do
  use Ecto.Migration

  def change do
    alter table(:payment_schedules) do
      add(:reminded_at, :utc_datetime)
    end
  end
end
