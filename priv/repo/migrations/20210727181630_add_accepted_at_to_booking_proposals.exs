defmodule Picsello.Repo.Migrations.AddAcceptedAtToBookingProposals do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:accepted_at, :utc_datetime)
    end
  end
end
