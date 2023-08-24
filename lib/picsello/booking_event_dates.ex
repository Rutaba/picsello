defmodule Picsello.BookingEventDates do
  alias Picsello.{Repo, BookingEventDate}
  import Ecto.Query

  def duplicate_booking_event_dates(params) do
    %BookingEventDate{}
    |> BookingEventDate.changeset(params)
    |> Repo.insert()
  end

  def get_booking_events_dates(booking_event_id) do
    from(event_dates in BookingEventDate,
      where: event_dates.booking_event_id == ^booking_event_id,
      order_by: [desc: event_dates.date]
    )
    |> Repo.all()
  end
end
