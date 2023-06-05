defmodule PicselloWeb.Live.Calendar.Shared.ConnectModal do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog">
      <h1 class="flex justify-between mb-4 text-3xl font-bold">
        Connect calendar
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2"/>
        </button>
      </h1>
      <img src="/images/calendar-sync-smaller.jpg" />
      <p class="font-bold mt-4">Securely connect your calendar so we can:</p>
      <ul class="list-disc ml-4">
        <li>Create new events from Picsello actions (bookings and shoots)</li>
        <li>Delete Events created by Picsello</li>
        <li>Read Events from Calendars you've authorized to have singular view of your business in one spot</li>
      </ul>
      <PicselloWeb.LiveModal.footer class="pt-8">
        <a class="btn-primary" id="button-connect" href={@nylas_url}>Connect Calendar</a>
        <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
      </PicselloWeb.LiveModal.footer>
    </div>
    """
  end

  def open(%{assigns: _assigns} = socket, %{nylas_url: nylas_url} = _params) do
    socket |> open_modal(__MODULE__, %{nylas_url: nylas_url})
  end
end
