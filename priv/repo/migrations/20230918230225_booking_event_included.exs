defmodule Picsello.Repo.Migrations.BookingEventIncluded do
  use Ecto.Migration

  def change do
    alter table(:booking_events) do
      add(:include_questionnaire?, :boolean, default: true)
    end
  end
end
