defmodule PicselloWeb.Calendar.BookingEvents.Shared do
  @moduledoc "shared functions for booking events"

  # tells us if the created/duplicated booking event is complete or not
  # if we dont have dates or a package_template_id, then its incomplete
  # similarly its complete if both dates and package_template_id exist
  def incomplete_status?(%{package_template_id: nil}), do: true
  def incomplete_status?(%{dates: []}), do: true
  def incomplete_status?(_), do: false

  # will be true if the status matches in the array <status_list>
  def disabled?(booking_event, status_list), do: booking_event.status in status_list
end
