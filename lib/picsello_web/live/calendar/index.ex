defmodule PicselloWeb.Live.Calendar.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 center-container">
      <div class="flex items-end justify-between mt-4 md:justify-start">
        <div class="flex text-4xl font-bold items-center">
          <.back_button to={Routes.home_path(@socket, :index)} class="mt-2"/>
          Calendar
        </div>
        <.live_link to={Routes.calendar_settings_path(@socket, :settings)} class="flex text-md items-center px-2 py-1 font-sans border rounded-lg hover:opacity-75 border-blue-planning-300 ml-5 shadow-lg">
          <.icon name="settings" class="w-4 h-4 mr-1 fill-current text-blue-planning-300" />
          Settings
        </.live_link>
        <div class="fixed bottom-0 left-0 right-0 z-4 flex flex-shrink-0 w-full sm:p-0 p-6 mt-auto sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto sm:ml-auto">
          <.live_link to={Routes.calendar_booking_events_path(@socket, :index)} class="w-full md:w-auto btn-primary text-center">
            Manage booking events
          </.live_link>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <div phx-hook="Calendar" class="w-full" id="calendar" data-time-zone={@current_user.time_zone} data-feed-path={Routes.calendar_feed_path(@socket, :index)}></div>
    </div>
    """
  end
end
