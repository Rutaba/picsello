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
    <div class="modal">
      <.close_x close_event={@close_event} myself={@myself} />
      <div class="flex items-center mb-1 justify-center">
        <.icon name="confetti-welcome" class="w-12 h-12" />
        <h1 class="text-center text-4xl ml-4 font-bold">Welcome to the Picsello Family!</h1>
      </div>
      <h2 class="text-center text-base-250 mb-8 text-lg">What would you like to do today?</h2>
      <div class="grid lg:grid-cols-3 gap-6">
        <div class="grid-span-1 flex border rounded-lg welcome-column cursor-pointer">
          <div class="p-8 flex flex-col justify-between items-center" phx-click="modal_action" phx-value-id="client_booking" phx-target={@myself}>
            <h3 class="text-2xl text-blue-planning-300 font-bold text-center" >Explore client booking</h3>
            <img src="/images/events-1.png" class="aspect-video object-cover my-12 drop-shadow-xl" />
            <button type="button" class="btn-secondary">Get started</button>
          </div>
        </div>
        <div class="grid-span-1 flex border rounded-lg welcome-column cursor-pointer">
          <div class="p-8 flex flex-col justify-between items-center" phx-click="modal_action" phx-value-id="gallery" phx-target={@myself}>
            <h3 class="text-2xl text-blue-planning-300 font-bold text-center">Explore unlimited galleries</h3>
            <img src="/images/galleries-1.png" class="aspect-video object-cover my-12 drop-shadow-xl" />
            <button type="button" class="btn-secondary">Get started</button>
          </div>
        </div>
        <div class="grid-span-1 flex border rounded-lg welcome-column cursor-pointer">
          <div class="p-8 flex flex-col justify-between items-center">
            <a href="https://www.picsello.com/request-a-demo" target="_blank" rel="noreferrer"><h3 class="text-2xl text-blue-planning-300 font-bold text-center" phx-click="modal_action" phx-value-id="demo" phx-target={@myself}>Watch or join a demo</h3></a>
            <iframe src="https://www.youtube.com/embed/THCQu4BZgqY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen class="aspect-video my-12"></iframe>
            <a href="https://www.picsello.com/request-a-demo" target="_blank" rel="noreferrer" class="btn-secondary" phx-click="modal_action" phx-value-id="demo" phx-target={@myself}>Join a demo</a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "modal_action",
        %{"id" => id},
        %{assigns: %{close_event: close_event}} = socket
      ) do
    send(socket.parent_pid, {:close_event, %{event_name: close_event, link: id}})

    socket
    |> noreply()
  end

  @impl true
  def handle_event(
        "close_event",
        %{},
        %{assigns: %{close_event: close_event}} = socket
      ) do
    send(socket.parent_pid, {:close_event, %{event_name: close_event}})

    socket |> noreply()
  end

  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, assigns)
  end
end
