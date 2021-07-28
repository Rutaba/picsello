defmodule Picsello.Repo.Migrations.AddSignedAtToBookingProposals do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:signed_at, :utc_datetime)
      add(:signed_legal_name, :text)
    end
  end
end
