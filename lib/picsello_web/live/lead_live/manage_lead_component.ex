defmodule PicselloWeb.LeadLive.ManageLeadComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Job}

  @impl true
  def render(assigns) do
    ~L"""
    <div class="max-w-md modal">
      <h2 class="text-xs font-semibold tracking-widest text-gray-400 uppercase">Manage <%= Job.name(@job) %></h2>
      <button class="mt-4 btn-row"
        title="Archive lead"
        type="button"
      >
        Send a follow up email
        <%= icon_tag(@socket, "forth", class: "stroke-current h-4 w-4") %>
      </button>
      <button class="mt-4 btn-row"
        title="Archive lead"
        type="button"
      >
        Archive lead
        <%= icon_tag(@socket, "forth", class: "stroke-current h-4 w-4") %>
      </button>
      <button class="w-full mt-8 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
        Close
      </button>
    </div>
    """
  end

  def open_modal(%{assigns: assigns} = socket) do
    socket
    |> open_modal(__MODULE__, %{
      assigns: assigns |> Map.take([:job])
    })
  end
end
