defmodule PicselloWeb.Calendar.BookingEvents.Shared do
@moduledoc "shared functions for booking events"
  use Phoenix.HTML
  use Phoenix.Component

  import import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  alias Picsello.{BookingEvents, Repo}

  def handle_event(
        "duplicate-event",
        params,
        %{assigns: %{current_user: %{organization_id: org_id}}} = socket
      ) do
    to_duplicate_booking_event =
      BookingEvents.get_booking_event!(
        org_id,
        get_id(params, socket)
      )
      |> Repo.preload([:jobs])
      |> Map.delete(:__meta__)
      |> Map.delete(:__struct__)
      |> Map.put(:status, :active)

    case BookingEvents.duplicate_booking_event(to_duplicate_booking_event) do
      {:ok, booking_event} ->
        socket
        |> redirect(to: "/booking-events/#{booking_event.id}")

      {:error, _} ->
        socket
        |> put_flash(:error, "Unable to duplicate event")
    end
    |> noreply()
  end

  def handle_event("new-event", %{}, socket),
    do:
      socket
      |> PicselloWeb.Shared.SelectionPopupModal.open(%{
        heading: "Create a Booking Event",
        title_one: "Single Event",
        subtitle_one: "Best for a single weekend or a few days you’d like to fill.",
        icon_one: "calendar-add",
        btn_one_event: "create-single-event",
        title_two: "Repeating Event",
        subtitle_two:
          "Best for an event you’d like to run every week, weekend, every month, etc.",
        icon_two: "calendar-repeat",
        btn_two_event: "create-repeating-event"
      })
      |> noreply()

  def handle_event("confirm-archive-event", params, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Are you sure?",
      subtitle: """
      Are you sure you want to archive this event?
      """,
      confirm_event: "archive_event_#{get_id(params, socket)}",
      confirm_label: "Yes, archive",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  def handle_event("confirm-disable-event", params, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      title: "Disable this event?",
      subtitle: """
      Disabling this event will hide all availability for this event and prevent any further booking. This is also the first step to take if you need to cancel an event for any reason.
      Some things to keep in mind:
        • If you are no longer able to shoot at the date and time provided, let your clients know. We suggest offering them a new link to book with once you reschedule!
        • You may need to refund any payments made to prevent confusion with your clients.
        • Archive each job individually in the Jobs page if you intend to cancel it.
        • Reschedule if possible to keep business coming in!
      """,
      confirm_event: "disable_event_#{get_id(params, socket)}",
      confirm_label: "Disable Event",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  defp get_id(%{"event-id" => id}, _assigns), do: id
  defp get_id(%{}, %{assigns: %{booking_event: booking_event}}), do: booking_event.id

  # tells us if the created/duplicated booking event is complete or not
  # if we dont have dates or a package_template_id, then its incomplete
  # similarly its complete if both dates and package_template_id exist
  def incomplete_status?(%{package_template_id: nil}), do: true
  def incomplete_status?(%{dates: []}), do: true
  def incomplete_status?(_), do: false

  # will be true if the status matches in the array <status_list>
  def disabled?(booking_event, status_list), do: booking_event.status in status_list
end
