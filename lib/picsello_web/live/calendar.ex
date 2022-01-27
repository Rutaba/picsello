defmodule PicselloWeb.Live.Calendar do
  @moduledoc false
  use PicselloWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 center-container">

      <div phx-hook="Calendar" class="w-full" id="calendar" data-time-zone={@current_user.time_zone} data-feed-path={Routes.calendar_feed_path(@socket, :index)}>
      </div>

    </div>
    """
  end
end
