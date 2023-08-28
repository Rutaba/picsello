defmodule Picsello.Repo.Migrations.RemoveOldDatesFieldFromBookingEvents do
  use Ecto.Migration

  @table :booking_events
  def up do
    alter table(@table) do
      remove(:old_dates)
    end
  end

  def down do
    alter table(@table) do
      add(:old_dates, :map, null: true)
    end
  end
end
