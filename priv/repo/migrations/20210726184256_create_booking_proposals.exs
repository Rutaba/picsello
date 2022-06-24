defmodule Picsello.Repo.Migrations.CreateBookingProposals do
  use Ecto.Migration

  def change do
    create table(:booking_proposals) do
      add(:job_id, references(:jobs, on_delete: :nothing))

      timestamps()
    end

    create(index(:booking_proposals, [:job_id]))
  end
end
