defmodule Mix.Tasks.PopulateBookingEventDates do
  @moduledoc """
    Mix task for populating booking_event dates ---> booking_event_dates
  """

  use Mix.Task

  import Ecto.Query, warn: false

  alias Picsello.{Repo, BookingEvent, BookingEventDatesMigration, BookingEventDate}


  def run(_) do
    load_app()

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

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
