defmodule PicselloWeb.LeadLive.ProposalMessageSentComponent do
  @moduledoc false

  use PicselloWeb, :live_component

  defmodule CloseButton do
    @moduledoc "custom close button"
    use PicselloWeb, :live_component

    def render(assigns) do
      ~L"""
        <button class="w-full btn-primary" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
      """
    end
  end

  @impl true
  def render(assigns) do
    ~L"""
    <div class="max-w-md p-8 mx-auto">
      <%= icon_tag(@socket, "confetti", class: "h-16") %>
      <h1 class="text-3xl font-semibold">Email sent</h1>
      <p class="pt-4">Yay! Your email has been successfully sent</p>

      <%= render_block @inner_block %>
    </div>
    """
  end

  @impl true
  def handle_event("accept", %{}, socket), do: socket |> close_modal() |> noreply()

  def open_modal(socket) do
    socket
    |> open_modal(__MODULE__, %{
      show_x: false,
      assigns: %{},
      footer: CloseButton
    })
  end
end
