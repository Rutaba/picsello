defmodule Picsello.Repo.Migrations.AddIsRepeatingToBookingEvents do
  use Ecto.Migration

  def up do
    alter table(:booking_events) do
      add(:is_repeating, :boolean, default: false)
    end
  end

  def down do
    alter table(:booking_events) do
      remove(:is_repeating)
    end
  end
end
