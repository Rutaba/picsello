defmodule PicselloWeb.Calendar.BookingEvents.Shared do
  @moduledoc "shared functions for booking events"
  use Phoenix.HTML
  use Phoenix.Component

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers

  alias PicselloWeb.{
    Live.Calendar.BookingEvents.Index,
    Shared.SelectionPopupModal,
    PackageLive.WizardComponent
  }

  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{BookingEvents, BookingEvent, BookingEventDate, Repo}
  alias Picsello.{BookingEvents, BookingEvent, BookingEventDate, BookingEventDates, Repo}
  alias BookingEventDate.SlotBlock
  alias Ecto.Multi

  def handle_event(
        "duplicate-event",
        params,
        %{assigns: %{current_user: %{organization_id: org_id}}} = socket
      ) do
    to_duplicate_booking_event =
      BookingEvents.get_booking_event!(
        org_id,
        fetch_booking_event_id(params, socket)
      )
      |> Repo.preload([:dates])
      |> Map.put(:status, :active)
      |> Map.from_struct()

    to_duplicate_event_dates =
      to_duplicate_booking_event.dates
      |> Enum.map(fn t ->
        t
        |> Map.replace(:date, nil)
        |> Map.replace(:slots, BookingEventDates.transform_slots(t.slots))
      end)

    multi =
      Multi.new()
      |> Multi.insert(
        :duplicate_booking_event,
        BookingEvent.duplicate_changeset(to_duplicate_booking_event)
      )

    to_duplicate_event_dates
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {event_date, i}, multi ->
      multi
      |> Multi.insert(
        "duplicate_booking_event_date_#{i}",
        fn %{duplicate_booking_event: event} ->
          BookingEventDate.changeset(%{
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

      {:error, :duplicate_booking_event, _, _} ->
        socket
        |> put_flash(:error, "Unable to duplicate event")

      _ ->
        socket
        |> put_flash(:error, "Unexpected error")
    end
    |> noreply()
  end

  def handle_event("new-event", %{}, socket),
    do:
      socket
      |> SelectionPopupModal.open(%{
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
      confirm_event: "archive_event_#{fetch_booking_event_id(params, socket)}",
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
      confirm_event: "disable_event_#{fetch_booking_event_id(params, socket)}",
      confirm_label: "Disable Event",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  def handle_event(
        "enable-event",
        params,
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    params
    |> fetch_booking_event_id(socket)
    |> BookingEvents.enable_booking_event(organization.id)
    |> case do
      {:ok, event} ->
        socket
        |> assign_events(BookingEvents.preload_booking_event(event))
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
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    params
    |> fetch_booking_event_id(socket)
    |> BookingEvents.enable_booking_event(organization.id)
    |> case do
      {:ok, event} ->
        socket
        |> assign_events(BookingEvents.preload_booking_event(event))
        |> put_flash(:success, "Event unarchive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error unarchiving event")
    end
    |> noreply()
  end

  def handle_info(
        {:update_templates, %{templates: templates}},
        %{assigns: %{modal_pid: modal_pid}} = socket
      ) do
    send_update(modal_pid, WizardComponent, id: WizardComponent, templates: templates)

    socket
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "disable_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.disable_booking_event(id, current_user.organization_id) do
      {:ok, event} ->
        socket
        |> assign_events(BookingEvents.preload_booking_event(event))
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
        |> assign_events(BookingEvents.preload_booking_event(event))
        |> put_flash(:success, "Event archive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error archiving event")
    end
    |> close_modal()
    |> noreply()
  end

  def overlap_time?(blocks), do: BookingEvents.overlap_time?(blocks)

  @doc """
  Edits the status of booking event date slots.

  This function takes a list of booking event date slots and edits their status. It iterates through each slot
  in the list and sets the status to either `:hide` or `:open` based on the existing status. If the current
  status is `:hide`, it remains unchanged; otherwise, it is updated to `:open`. This function is typically
  used to toggle the visibility of slots.

  ## Parameters

  - `slots` ([%SlotBlock{}]): A list of booking event date slots to edit.

  ## Returns

  A list of updated booking event date slots with modified status.

  ## Example

  ```elixir
  # Edit the status of booking event date slots
  iex> slots = [%SlotBlock{status: :hide}, %SlotBlock{status: :open}]
  iex> edit_slots_status(%{slots: slots})
  [%SlotBlock{status: :hide}, %SlotBlock{status: :open}]

  ## Notes

  This function is useful for modifying the status of booking event date slots, typically used to control their visibility
  """
  @spec edit_slots_status(map()) :: [SlotBlock.t()]
  def edit_slots_status(%{slots: slots}) do
    slots
    |> Enum.map(fn s ->
      if s.status == :hidden, do: %{s | is_hide: true}, else: s
    end)
  end

  @doc """
  Converts a list of structs to a list of maps.

  This function takes a list of structs and converts each struct into a map using the `Map.from_struct/1` function.
  It returns a new list containing the converted maps. This can be useful when you need to work with data in map
  format, such as when interacting with certain Elixir functions or libraries that expect map data.

  ## Parameters

  - `data` ([struct()]): A list of structs to be converted into maps.

  ## Returns

  A list of maps, where each map corresponds to a struct in the original list.

  ## Example

  ```elixir
  # Convert a list of structs to a list of maps
  iex> data = [%MyStruct{id: 1, name: "Alice"}, %MyStruct{id: 2, name: "Bob"}]
  iex> to_map(data)
  [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]

  ## Notes

  This function simplifies the process of converting structs to maps for various Elixir operations that work with maps.
  """
  @spec to_map(data :: [struct()]) :: [map()]
  def to_map(data), do: Enum.map(data, &Map.from_struct(&1))

  def assign_events(
        %{assigns: %{booking_event: _booking_event, current_user: %{organization: organization}}} =
          socket,
        event
      ),
      do: assign(socket, :booking_event, put_url_booking_event(event, organization, socket))

  def assign_events(%{assigns: %{booking_events: _booking_events}} = socket, _event),
    do: Index.assign_booking_events(socket)

  def count_booked_slots(slot),
    do: Enum.count(slot, fn s -> s.status == :booked || s.status == :reserved end)

  def count_available_slots(slot), do: Enum.count(slot, fn s -> s.status == :open end)
  def count_hidden_slots(slot), do: Enum.count(slot, fn s -> s.status == :hidden end)

  def date_formatter(date), do: "#{Timex.month_name(date.month)} #{date.day}, #{date.year}"

  # tells us if the created/duplicated booking event is complete or not
  # if we dont have dates or a package_template_id, then its incomplete
  # similarly its complete if both dates and package_template_id exist
  def incomplete_status?(%{package_template_id: nil}), do: true
  def incomplete_status?(%{dates: []}), do: true
  def incomplete_status?(_), do: false

  # will be true if the status matches in the array <status_list>
  def disabled?(booking_event, status_list), do: booking_event.status in status_list

  def put_url_booking_event(booking_event, organization, socket),
    do:
      booking_event
      |> Map.put(
        :url,
        Routes.client_booking_event_url(
          socket,
          :show,
          organization.slug,
          booking_event.id
        )
      )

  # to cater different handle_event and info calls
  # if we get booking-event-id in params (1st argument) it returns the id
  # otherwise get the id from socket
  defp fetch_booking_event_id(%{"event-id" => id}, _assigns), do: id

  defp fetch_booking_event_id(%{}, %{assigns: %{booking_event: booking_event}}),
    do: booking_event.id

  def calculate_dates(booking_event_date, selected_days),
    do: BookingEvents.calculate_dates(booking_event_date, selected_days)
end
