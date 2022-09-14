defmodule Picsello.Repo.Migrations.AddBookingEventIdToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add(:booking_event_id, references(:booking_events, on_delete: :nothing))
    end

    create(index(:jobs, [:booking_event_id]))
  end
end
