defmodule PicselloWeb.Live.Calendar.BookingEvents do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]
  alias Picsello.BookingEvents

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_booking_events()
    |> ok()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :new}} = socket) do
    socket
    |> open_wizard()
    |> noreply()
  end

  @impl true
  def handle_params(_, _, socket) do
    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-6 py-2 center-container">
      <div class="flex text-4xl items-center">
        <.back_button to={Routes.calendar_index_path(@socket, :index)} class="lg:hidden"/>
        <.crumbs class="text-base text-base-250">
          <:crumb to={Routes.calendar_index_path(@socket, :index)}>Calendar</:crumb>
          <:crumb>Booking events</:crumb>
        </.crumbs>
      </div>

      <hr class="mt-2 border-white" />

      <div class="flex items-center justify-between lg:mt-2 md:justify-start">
        <div class="flex text-4xl font-bold items-center">
          <.back_button to={Routes.calendar_index_path(@socket, :index)} class="hidden lg:flex mt-2"/>
          Booking events
        </div>
        <%= unless Enum.empty?(@booking_events) do %>
          <div class="fixed bottom-0 left-0 right-0 z-4 flex flex-shrink-0 w-full sm:p-0 p-6 mt-auto sm:mt-0 sm:bottom-auto sm:ml-auto sm:static sm:items-start sm:w-auto">
            <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="w-full md:w-auto btn-primary text-center">
              Add booking event
            </.live_link>
          </div>
        <% end %>
      </div>

      <hr class="mt-4 sm:mt-10" />
    </div>

    <%= if Enum.empty?(@booking_events) do %>
      <div class="flex flex-col justify-between flex-auto mt-4 p-6 center-container lg:flex-none">
        <div class="flex flex-col">
          <h1 class="mt-3 mb-3 text-4xl font-bold lg:text-5xl">Oh hey!</h1>
          <p class="block text-lg lg:text-2xl lg:w-1/2">You don’t have any booking events created at the moment. Booking events allow you to create events and pages to send to your clients so they can sign up for mini-sessions shoots.</p>
        </div>
        <div class="lg:inline-flex">
          <.live_link to={Routes.calendar_booking_events_path(@socket, :new)} class="flex justify-center mt-5 text-lg px-7 btn-primary">
            Add booking event
          </.live_link>
        </div>
      </div>
    <% else %>
      <div class="p-6 center-container">
        <div class="hidden sm:grid sm:grid-cols-4 gap-2 border-b-8 border-blue-planning-300 font-semibold text-lg pb-6">
          <div class="sm:col-span-2">Event Details</div>
          <div>Bookings so far</div>
          <div>Actions</div>
        </div>
        <%= for event <- @booking_events do %>
          <div class="grid sm:grid-cols-4 gap-2 border p-3 sm:pt-0 sm:px-0 sm:pb-4 sm:border-b sm:border-t-0 sm:border-x-0 rounded-lg sm:rounded-none border-gray-100 mt-4">
            <.details_cell booking_event={event} />
            <hr class="sm:hidden border-gray-100" />
            <.bookings_cell booking_event={event} />
            <.actions_cell booking_event={event} />
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp details_cell(assigns) do
    ~H"""
    <div class="sm:col-span-2 grid sm:flex gap-4 sm:gap-0">
      <img class="h-32 aspect-[3/2] object-cover rounded-lg" src={@booking_event.thumbnail_url} />
      <div class="flex flex-col justify-center sm:ml-4">
        <p class="font-semibold"><%= @booking_event.date |> Calendar.strftime("%m/%d/%Y") %></p>
        <p class="text-xl font-semibold underline text-blue-planning-300"><%= @booking_event.name %></p>
        <p class="text-gray-400"><%= @booking_event.package_name %></p>
        <p class="text-gray-400"><%= @booking_event.duration_minutes %> minutes</p>
      </div>
    </div>
    """
  end

  defp bookings_cell(assigns) do
    ~H"""
    <div class="flex flex-col justify-center">
      <p>0 bookings so far</p>
    </div>
    """
  end

  defp actions_cell(assigns) do
    ~H"""
    <div>
    </div>
    """
  end

  @impl true
  def handle_info({:update, %{booking_event: _booking_event}}, socket) do
    socket
    |> assign_booking_events()
    |> put_flash(:success, "Booking event saved successfully")
    |> noreply()
  end

  @impl true
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> push_patch(to: Routes.calendar_booking_events_path(socket, :index))
    |> noreply()
  end

  defp open_wizard(socket, assigns \\ %{}) do
    socket
    |> open_modal(PicselloWeb.Live.Calendar.BookingEventWizard, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user]))
    })
  end

  defp assign_booking_events(%{assigns: %{current_user: current_user}} = socket) do
    booking_events =
      BookingEvents.get_booking_events(current_user.organization_id)
      |> Enum.map(fn booking_event ->
        booking_event
        |> Map.take([:id, :name, :thumbnail_url, :duration_minutes])
        |> Map.put(:date, booking_event.dates |> hd |> Map.get(:date))
        |> Map.put(:package_name, booking_event.package_template.name)
      end)

    socket
    |> assign(booking_events: booking_events)
  end
end
