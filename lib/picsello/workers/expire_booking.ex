defmodule Picsello.Workers.ExpireBooking do
  @moduledoc "Background job to expire a lead created from a booking event"

  use Oban.Worker, unique: [fields: [:args, :worker]]
  alias Picsello.{Repo, Job, BookingEventDates, BookingEvents}

  def perform(%Oban.Job{args: %{"id" => job_id, "booking_date_id" => booking_date_id}}) do
    Job
    |> Repo.get(job_id)
    |> BookingEvents.expire_booking()

    booking_date = BookingEventDates.get_booking_date(booking_date_id)
    booking_event = Map.get(booking_date, :booking_event, nil)
    BookingEventDates.update_booking_event_date_slots(booking_event, booking_date)
  end
end
