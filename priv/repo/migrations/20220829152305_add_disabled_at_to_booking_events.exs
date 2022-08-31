defmodule Picsello.Repo.Migrations.AddDisabledAtToBookingEvents do
  use Ecto.Migration

  def change do
    alter table(:booking_events) do
      add(:disabled_at, :utc_datetime)
    end
  end
end
