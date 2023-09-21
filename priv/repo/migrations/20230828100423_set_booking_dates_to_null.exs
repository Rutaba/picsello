defmodule Picsello.Repo.Migrations.SetBookingDatesToNull do
  use Ecto.Migration

  @table "booking_events"
  def up do
    alter table(@table) do
      modify(:dates, :map, null: true)
      add(:old_dates, :map, null: true)
    end

    flush()
    execute("UPDATE #{@table} SET old_dates=dates, dates=null")
  end

  def down do
    alter table(@table) do
      modify(:dates, :map, null: false)
      remove(:old_dates)
    end
  end
end
