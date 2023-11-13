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
      <%= if Enum.member?(@current_user.onboarding_flow_source, "mastermind") do %>
        <h1 class="welcome-text text-3xl font-bold mb-4 pr-8">Welcome to Picsello’s Mastermind!</h1>
        <h2>Here are some notes for you:</h2>
        <ul class="list-disc space-y-1 list-inside pl-5">
          <li><a href="https://www.facebook.com/groups/picsellobusinessmastermind" class="underline text-blue-planning-300" target="_blank" rel="noopener noreferrer">Join the Private Facebook Group</a> for resources and schedule of events</li>
          <li>You get Picsello as a part of Mastermind Subscription. Take a look around!</li>
          <li><button class="underline text-blue-planning-300" onclick="Calendly.initPopupWidget({url: 'https://calendly.com/teampicsello/picsello-orientation'});return false;" type="button">Schedule an orientation</button> call to get familiar with Picsello (if you choose to use it) and the Mastermind</li>
        </ul>
        <button class="btn-primary w-full mt-4" type="button" phx-click="close_event" phx-target={@myself}>Close</button>
      <% else %>
        <h1 class="welcome-text text-3xl font-bold mb-4 pr-8">Welcome to Picsello!</h1>
        <p class="mb-4 text-base-250">We know learning new software isn’t fun and you would rather be photographing—don’t worry, we’ve got you!</p>
        <p class="mb-4 text-base-250">Simply schedule your Orientation Call today and we’ll help you set up your account, see how it works for your business, and get answers to any questions you have. We can’t wait to meet you!</p>
        <div class="flex gap-4 flex-wrap">
          <button class="btn-primary" type="button" onclick="Calendly.initPopupWidget({url: 'https://calendly.com/teampicsello/picsello-orientation'});return false;" phx-click="close_event" phx-target={@myself}>Let's do it</button>
          <button class="underline text-blue-planning-300 text-sm" type="button" phx-click="close_event" phx-target={@myself}>Not yet, I want to play around first</button>
        </div>
      <% end %>
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
