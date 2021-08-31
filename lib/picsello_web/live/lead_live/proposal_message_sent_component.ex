defmodule PicselloWeb.LeadLive.ProposalMessageSentComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <div class="max-w-md modal">
      <%= icon_tag(@socket, "confetti", class: "h-16") %>
      <h1 class="text-3xl font-semibold">Email sent</h1>
      <p class="pt-4">Yay! Your email has been successfully sent</p>
      <button class="w-full mt-4 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
        Close
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("accept", %{}, socket), do: socket |> close_modal() |> noreply()

  def open_modal(socket) do
    socket
    |> open_modal(__MODULE__, %{
      assigns: %{}
    })
  end
end
