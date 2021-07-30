defmodule Picsello.Repo.Migrations.AddPaidAtToBookingProposal do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:deposit_paid_at, :utc_datetime)
    end
  end
end
