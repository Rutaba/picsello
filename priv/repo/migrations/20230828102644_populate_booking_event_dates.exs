defmodule Picsello.Repo.Migrations.PopulateBookingEventDates do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Picsello.{Repo, BookingEvent, BookingEventDatesMigration, BookingEventDate}

  def change do
    from(e in BookingEvent, where: not is_nil(e.old_dates))
    |> Repo.all()
    |> Enum.map(fn booking_event ->
      booking_event_dates =
        Enum.map(booking_event.old_dates, fn date ->
          BookingEventDatesMigration.available_times(booking_event, date.date)
        end)

      Repo.insert_all(BookingEventDate, booking_event_dates)
    end)
  end
end
