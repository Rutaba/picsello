defmodule Picsello.Repo.Migrations.AddRemainderPaidAtToProposals do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:remainder_paid_at, :utc_datetime)
    end

    create(
      constraint(:booking_proposals, "must_pay_deposit_before_remainder",
        check: "deposit_paid_at is not null or remainder_paid_at is null"
      )
    )
  end
end
