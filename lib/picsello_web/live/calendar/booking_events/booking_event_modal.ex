defmodule PicselloWeb.Live.Calendar.BookingEventModal do
  @moduledoc false
  use PicselloWeb, :live_component
  import Phoenix.Component

  import PicselloWeb.ShootLive.Shared, only: [duration_options: 0]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.BookingEvent.EventDate

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(assign_event_keys(assigns))
    |> ok()
  end

  def assign_event_keys(assigns) do
    assigns
    |> Map.put_new(:booking_date, %EventDate{date: nil})
    |> Map.put_new(:is_valid, true)
    |> Map.put_new(:can_edit, true)
    |> Map.put_new(:booking_count, 0)
    |> Map.put_new(:slots, [
      %{id: 1, title: "Open", status: "open", time: "4:45am - 5:00am"},
      %{id: 2, title: "Booked", status: "booked", time: "4:45am - 5:20am"},
      %{id: 3, title: "Booked (hidden)", status: "booked_hidden", time: "4:45am - 5:15am"}
    ])
    |> Map.put_new(:break_block_booked, false)
    |> Map.put_new(:params, %{})
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
      <.form :let={f} for={} phx-change="validate" phx-submit="submit" phx-target={@myself} >
        <div class="grid grid-cols-11 gap-5 mt-8">
          <div class="col-span-3">
            <%= labeled_input f, :date, type: :date_input, min: Date.utc_today(), class: "w-full" %>
          </div>
          <div class="col-span-4 flex items-center pl-4">
            <div class="grow">
              <%= labeled_input f, :start_time, type: :time_input, class: "w-11/12" %>
            </div>
            <div class="pt-5 mr-4"> - </div>
            <div class="grow">
              <%= labeled_input f, :end_time, type: :time_input, class: "w-11/12" %>
            </div>
          </div>
          <div class="col-span-4 flex gap-5">
            <div class="grow">
              <%= labeled_select f, :session_gap, buffer_options(), class: "" %>
            </div>
            <div class="grow">
              <%= labeled_select f, :session_length, duration_options(), class: "" %>
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
        <%= for slot <- @slots do %>
          <div class="mt-4 grid grid-cols-5 items-center">
            <div class="col-span-2">
              <%= slot.time %>
            </div>
            <div>
              <%= slot.title %>
            </div>
            <div class="col-span-2 flex justify-end pr-2">
              <%= input f, :active, type: :checkbox, class: "checkbox w-6 h-6" %>
              <div class="ml-2"> Show block as booked (break)</div>
            </div>
          </div>
        <% end %>
        <.footer>
          <button class="btn-primary" title="Save" type="submit" disabled={!@is_valid} phx-disable-with="Save">
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
  def handle_event("validate", _params, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event("submit", _params, socket) do
    socket
    |> put_flash(:success, "Date Added")
    |> close_modal()
    |> noreply()
  end

  defp heading_title(booking_date), do: if(booking_date.date, do: "Edit Date", else: "Add Date")

  defp buffer_options() do
    for(
      duration <- [5, 10, 15, 20, 30, 45, 60],
      do: {dyn_gettext("duration-#{duration}"), duration}
    )
  end
end
