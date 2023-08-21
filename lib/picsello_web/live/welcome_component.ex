defmodule PicselloWeb.WelcomeComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dialog relative">
      <.close_x close_event="close_event" myself={@myself} />
      <h1 class="welcome-text text-3xl font-bold mb-4 pr-8">Welcome to Picsello!</h1>
      <p class="mb-4 text-base-250">We know learning new software isn’t fun and you would rather be photographing—don’t worry, we’ve got you!</p>
      <p class="mb-4 text-base-250">Simply schedule your Orientation Call today and we’ll help you set up your account, see how it works for your business, and get answers to any questions you have. We can’t wait to meet you!</p>
      <div class="flex gap-4 flex-wrap">
        <button class="btn-primary" type="button" onclick="Calendly.initPopupWidget({url: 'https://calendly.com/teampicsello/picsello-orientation'});return false;" phx-click="close_event" phx-target={@myself}>Let's do it</button>
        <button class="underline text-blue-planning-300 text-sm" type="button" phx-click="close_event" phx-target={@myself}>Not yet, I want to play around first</button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "close_event",
        _params,
        socket
      ) do
    send(
      socket.parent_pid,
      {:close_event, %{event_name: "toggle_welcome_event"}}
    )

    socket
    |> noreply()
  end

  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, assigns)
  end
end
