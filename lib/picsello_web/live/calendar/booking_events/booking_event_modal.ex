defmodule PicselloWeb.Live.Calendar.BookingEventModal do
  @moduledoc false
  use PicselloWeb, :live_component

  import PicselloWeb.ShootLive.Shared, only: [duration_options: 0]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.BookingEventDate

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_event_keys(assigns)
    |> assign_changeset(%{"time_blocks" => [%{}], "slots" => []})
    |> ok()
  end

  def assign_event_keys(socket, assigns) do
    # TODO: This will be remove in later version
    assigns =
      Enum.into(assigns, %{
        slots: [
          %{id: 1, title: "Open", status: "open", time: "4:45am - 5:00am"},
          %{id: 2, title: "Booked", status: "booked", time: "4:45am - 5:20am"},
          %{id: 3, title: "Booked (hidden)", status: "booked_hidden", time: "4:45am - 5:15am"}
        ]
      })

    socket |> assign(assigns)
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
              <%= labeled_select f, :duration_minutes, duration_options(), label: "Session length", prompt: "Select below" %>
            </div>
            <div class="grow">
              <%= labeled_select f, :buffer_minutes, buffer_options(), label: "Session Gap", prompt: "Select below", optional: true %>
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

        <div class="font-bold mt-6">You'll have <span class="text-blue-planning-300">10</span> open session blocks</div>
        <div class="mt-6 grid grid-cols-5 border-b-4 border-blue-planning-300 text-lg font-bold">
          <div class="col-span-2">Time</div>
          <div class="col-span-3">Status</div>
        </div>
        <!-- TODO slots section -->
        <%= inputs_for f, :slots, fn s -> %>
          <div class="mt-4 grid grid-cols-5 items-center">
            <div class="col-span-2">
              <%= s.slot_start %>
            </div>
            <div>
              <%= s.status %>
            </div>
            <div class="col-span-2 flex justify-end pr-2">
              <%= input s, :active, type: :checkbox, class: "checkbox w-6 h-6" %>
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
  def handle_event("validate", %{"booking_event_date" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("submit", _params, socket) do
    # TODO: Currentyly with minimal info
    socket
    |> put_flash(:success, "Date Added")
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

  defp assign_changeset(
         %{assigns: %{booking_date: booking_date}} = socket,
         params,
         action \\ nil
       ) do
    # TODO: will remove this in later version
    # event = current(changeset)
    changeset = booking_date |> BookingEventDate.changeset(params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end
end
