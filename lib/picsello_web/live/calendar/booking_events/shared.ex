defmodule PicselloWeb.Calendar.BookingEvents.Shared do
  @moduledoc "shared functions for booking events"
  use Phoenix.HTML
  use Phoenix.Component

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  alias PicselloWeb.{Live.Calendar.BookingEvents.Index}
  alias Picsello.{BookingEvents, BookingEvent, BookingEventDate, BookingEventDates, Repo}
  alias Ecto.Multi

  def handle_event(
        "duplicate-event",
        params,
        %{assigns: %{current_user: %{organization_id: org_id}}} = socket
      ) do
    old_booking_event_id = get_id(params, socket)

    to_duplicate_booking_event =
      BookingEvents.get_booking_event!(
        org_id,
        old_booking_event_id
      )
      |> Repo.preload([:jobs])
      |> Map.put(:status, :active)
      |> Map.from_struct()

    to_duplicate_event_dates =
      BookingEventDates.get_booking_events_dates(old_booking_event_id)
      |> Enum.map(fn t ->
        Map.replace(t, :slots, edit_slots_status(t))
      end)

    multi =
      Multi.new()
      |> Multi.insert(
        :duplicate_booking_event,
        BookingEvent.duplicate_changeset(%BookingEvent{}, to_duplicate_booking_event)
      )

    to_duplicate_event_dates
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {event_date, i}, multi ->
      multi
      |> Multi.insert(
        "duplicate_booking_event_date_#{i}",
        fn %{duplicate_booking_event: event} ->
          BookingEventDate.duplicate_changeset(%BookingEventDate{}, %{
            booking_event_id: event.id,
            location: event_date.location,
            address: event_date.address,
            session_length: event_date.session_length,
            session_gap: event_date.session_gap,
            time_blocks: to_map(event_date.time_blocks),
            slots: to_map(event_date.slots)
          })
        end
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{duplicate_booking_event: new_event}} ->
        socket
        |> redirect(to: "/booking-events/#{new_event.id}")

      {:error, _some_error} ->
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

  def handle_event(
        "enable-event",
        params,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.enable_booking_event(get_id(params, socket), current_user.organization_id) do
      {:ok, event} ->
        socket
        |> assign_events(preload_data(event))
        |> put_flash(:success, "Event enabled successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error enabling event")
    end
    |> noreply()
  end

  def handle_event(
        "unarchive-event",
        params,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.enable_booking_event(get_id(params, socket), current_user.organization_id) do
      {:ok, event} ->
        socket
        |> assign_events(preload_data(event))
        |> put_flash(:success, "Event unarchive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error unarchiving event")
    end
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "disable_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.disable_booking_event(id, current_user.organization_id) do
      {:ok, event} ->
        socket
        |> assign_events(preload_data(event))
        |> put_flash(:success, "Event disabled successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error disabling event")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "archive_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.archive_booking_event(id, current_user.organization_id) do
      {:ok, event} ->
        socket
        |> assign_events(preload_data(event))
        |> put_flash(:success, "Event archive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error archiving event")
    end
    |> close_modal()
    |> noreply()
  end

  def edit_slots_status(%{slots: slots}) do
    slots
    |> Enum.map(fn s ->
      if s.status == :hide do
        %{s | status: :hide}
      else
        %{s | status: :open}
      end
    end)
  end

  def to_map(data) do
    Enum.map(data, &Map.from_struct(&1))
  end

  def assign_events(%{assigns: %{booking_event: _booking_event}} = socket, event),
    do: assign(socket, :booking_event, event)

  def assign_events(%{assigns: %{booking_events: _booking_events}} = socket, _event),
    do: Index.assign_booking_events(socket)

  def count_booked_slots(slot),
    do: Enum.count(slot, fn s -> s.status == :book || s.status == :reserve end)

  def count_available_slots(slot), do: Enum.count(slot, fn s -> s.status == :open end)
  def count_hidden_slots(slot), do: Enum.count(slot, fn s -> s.status == :hide end)

  def date_formatter(date), do: "#{Timex.month_name(date.month)} #{date.day}, #{date.year}"

  # tells us if the created/duplicated booking event is complete or not
  # if we dont have dates or a package_template_id, then its incomplete
  # similarly its complete if both dates and package_template_id exist
  def incomplete_status?(%{package_template_id: nil}), do: true
  def incomplete_status?(%{dates: []}), do: true
  def incomplete_status?(_), do: false

  # checks if an event made has any date that is nil in its array of dates field
  def incomplete_dates?(%{dates: d}) do
    Enum.any?(d, fn x ->
      is_nil(x.date)
    end)
  end

  def preload_data(event),
    do:
      Repo.preload(event, [
        :dates,
        package_template: [:package_payment_schedules, :contract, :questionnaire_template]
      ])

  # will be true if the status matches in the array <status_list>
  def disabled?(booking_event, status_list), do: booking_event.status in status_list

  # to cater different handle_event and info calls
  # if we get booking-event-id in params (1st argument) it returns the id
  # otherwise get the id from socket
  defp get_id(%{"event-id" => id}, _assigns), do: id
  defp get_id(%{}, %{assigns: %{booking_event: booking_event}}), do: booking_event.id
end
