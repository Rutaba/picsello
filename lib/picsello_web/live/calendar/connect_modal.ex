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
        2-way calendar sync
        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2"/>
        </button>
      </h1>
      <img src="/images/calendar-sync-smaller.jpg" />
      <p class="font-bold mt-4">Securely connect your external and Picsello calendars so you can:</p>
      <ul class="list-disc ml-4">
        <li>Avoid schedule conflicts and double-bookings between your photography and personal calendars</li>
        <li>Have all your external calendar events and details will synced with your Picsello account and vice versa!</li>
      </ul>
      <PicselloWeb.LiveModal.footer class="pt-8">
        <a class="btn-primary" id="button-connect" href={@nylas_url}>Sync calendars</a>
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
