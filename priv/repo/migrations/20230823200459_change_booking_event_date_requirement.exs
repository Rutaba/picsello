defmodule Picsello.Repo.Migrations.ChangeBookingEventDateRequirement do
  use Ecto.Migration

  @table :booking_event_dates
  def up do
    alter table(@table) do
      modify(:date, :date,  null: true)
    end
  end

  def down do
    alter table(@table) do
      modify(:date, :date, null: false)
    end
  end
end
