defmodule Picsello.Repo.Migrations.AddSentToClientToBookingProposals do
  use Ecto.Migration

  def change do
    alter table(:booking_proposals) do
      add(:sent_to_client, :boolean, null: false, default: true)
    end
  end
end
