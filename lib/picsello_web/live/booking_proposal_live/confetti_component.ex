defmodule PicselloWeb.BookingProposalLive.ConfettiComponent do
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
    ~L"""
    <div class="max-w-md p-8 mx-auto">
      <%= icon_tag(@socket, "confetti", class: "h-16") %>
      <h1 class="text-3xl font-semibold">Thank you! Your session is now booked.</h1>
      <p class="pt-4">We are so excited to be working with you, thank you for your business. See you soon.</p>
      <div class="flex justify-center pt-12">
        <button phx-click="accept" phx-target="<%= @myself %>" class="w-full btn-primary">
           Whoo hoo!
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("accept", %{}, socket), do: socket |> close_modal() |> noreply()
end
