defmodule PicselloWeb.Live.Calendar.BookingEventModal do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.ShootLive.Shared, only: [duration_options: 0]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  alias Picsello.{BookingEventDate, BookingEventDates}
  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:open_slots, 0)
    |> case do
      %{assigns: %{booking_date: %BookingEventDate{id: nil}}} = socket ->
        socket |> assign_changeset(%{"time_blocks" => [%{}], "slots" => []})

      socket ->
        socket |> assign_changeset(%{})
    end
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />
      <div class="text-4xl font-bold"><%= heading_title(@booking_date) %></div>
      <div class="grid grid-cols-2 mt-4 gap-5">
        <div>
          <div class="text-blue-planning-300 bg-blue-100 w-14 h-6 pt-0.5 ml-1 text-center font-bold text-sm rounded-lg">Note</div>
          <p>Sessions blocks that are booked, in the process of booking, or reserved are locked. They will not adjust when making changes to any of your date settings.</p>
        </div>
        <div>
          <div class="text-blue-planning-300 bg-blue-100 w-14 h-6 pt-0.5 ml-1 text-center font-bold text-sm rounded-lg">Note</div>
          <p>Client details, discounts, reservations, and all other settings will be found after you save/close this modal.</p>
        </div>
      </div>
      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="submit" phx-target={@myself} >
        <div class="grid grid-cols-11 gap-5 mt-8">
          <div class="col-span-3">
            <%= labeled_input f, :date, type: :date_input, min: Date.utc_today(), class: "w-full" %>
          </div>
          <%= error_tag(f, :time_blocks, prefix: "Times", class: "text-red-sales-300 text-sm mb-2") %>
          <%= inputs_for f, :time_blocks, fn t -> %>
            <div class="col-span-4 flex items-center pl-4">
              <div class="grow">
                <%= labeled_input t, :start_time, type: :time_input, label: "Event Start", class: "w-11/12" %>
              </div>
              <div class="pt-5 mr-4"> - </div>
              <div class="grow">
                <%= labeled_input t, :end_time, type: :time_input, label: "Event End", class: "w-11/12" %>
              </div>
            </div>
          <% end %>
          <div class="col-span-4 flex gap-5">
            <div class="grow">
              <%= labeled_select f, :session_length, duration_options(), label: "Session length", prompt: "Select below" %>
            </div>
            <div class="grow">
              <%= labeled_select f, :session_gap, buffer_options(), label: "Session Gap", prompt: "Select below", optional: true %>
            </div>
          </div>
        </div>
        <div class="mt-6 flex items-center">
          <%= input f, :repeat, type: :checkbox, class: "checkbox w-6 h-6" %>
          <div class="ml-2"> Repeat dates?</div>
        </div>

        <div class="w-2/3 border-2 border-base-200 rounded-lg mt-4">
          <div class="font-bold p-4 bg-base-200">
            Repeat settings
          </div>
          <div class="p-4">
           Demo
          </div>

        </div>

        <div class="font-bold mt-6">You'll have <span class="text-blue-planning-300"><%= @open_slots %></span> open session blocks</div>
        <div class="mt-6 grid grid-cols-5 border-b-4 border-blue-planning-300 text-lg font-bold">
          <div class="col-span-2">Time</div>
          <div class="col-span-3">Status</div>
        </div>
         <%= inputs_for f, :slots, fn s -> %>
          <div class="mt-4 grid grid-cols-5 items-center">
          <div class="col-span-2">
            <%= hidden_input s, :slot_start %>
            <%= hidden_input s, :slot_end %>
            <%= parse_time(input_value(s, :slot_start)) <> "-" <> parse_time(input_value(s, :slot_end))%>
            </div>
            <div>
              <%= if to_string(input_value(s, :status)) == "hide", do: "Booked (Hidden)", else: input_value(s, :status) |> to_string() |> String.capitalize() %>
            </div>
            <div class="col-span-2 flex justify-end pr-2">
              <%= input s, :is_hide, type: :checkbox, checked: hidden_time?(s |> current |> Map.get(:status)), class: "checkbox w-6 h-6" %>
              <div class="ml-2"> Show block as booked (break)</div>
            </div>
          </div>
        <% end %>
        <.footer>
          <button class="btn-primary" title="Save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Save">
              Save
          </button>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
          </button>
        </.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "booking_event_date" => params,
          "_target" => ["booking_event_date", "slots", _, "is_hide"]
        },
        socket
      ) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("validate", %{"booking_event_date" => params}, socket) do
    socket |> assign_changeset_with_slots(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"booking_event_date" => params}, socket) do
    %{assigns: %{changeset: changeset}} = socket = assign_changeset(socket, params)

    case BookingEventDates.upsert_booking_event_date(changeset) do
      {:ok, booking_event} ->
        successfull_save(socket, booking_event)

      _ ->
        socket |> noreply()
    end
  end

  defp successfull_save(socket, booking_event_date) do
    send(self(), {:update, %{booking_event_date: booking_event_date}})

    socket
    |> close_modal()
    |> noreply()
  end

  defp heading_title(booking_date), do: if(booking_date.id, do: "Edit Date", else: "Add Date")

  defp buffer_options() do
    for(
      duration <- [5, 10, 15, 20, 30, 45, 60],
      do: {dyn_gettext("duration-#{duration}"), duration}
    )
  end

  defp assign_changeset(%{assigns: %{booking_date: booking_date}} = socket, params, action \\ nil) do
    changeset = booking_date |> BookingEventDate.changeset(params) |> Map.put(:action, action)
    event = current(changeset)
    open_slots = Enum.count(event.slots, &(&1.status == :open))

    socket |> assign(changeset: changeset, open_slots: open_slots)
  end

  defp assign_changeset_with_slots(
         %{assigns: %{booking_date: booking_date, booking_event: booking_event}} = socket,
         params,
         action
       ) do
    socket = socket |> assign_changeset(params, :validate)
    changeset = socket.assigns.changeset
    event = current(changeset)

    slots = event |> BookingEventDates.available_slots(booking_event)
    open_slots = Enum.count(event.slots, &(&1.status == :open))
    params = Map.put(params, "slots", slots)
    changeset = booking_date |> BookingEventDate.changeset(params) |> Map.put(:action, action)

    socket |> assign(changeset: changeset, open_slots: open_slots)
  end

  defp hidden_time?(:hide), do: true
  defp hidden_time?(_state), do: false

  defp parse_time(time), do: time |> Timex.format("{h12}:{0m} {am}") |> elem(1)
end
