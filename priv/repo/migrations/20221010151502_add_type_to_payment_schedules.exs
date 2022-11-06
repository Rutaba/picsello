defmodule Picsello.Repo.Migrations.AddTypeToPaymentSchedules do
  use Ecto.Migration

  def change do
    alter table(:payment_schedules) do
      add(:type, :string, default: "stripe")
    end
  end
end
