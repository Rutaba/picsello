defmodule Picsello.Repo.Migrations.AddShowOnProfileToBookingEvents do
  use Ecto.Migration

  @table "booking_events"
  def up do
    alter table(@table) do
      add :show_on_profile?, :boolean, default: false
    end
  end

  def down do
    alter table(@table) do
      remove :show_on_profile?
    end
  end
end
