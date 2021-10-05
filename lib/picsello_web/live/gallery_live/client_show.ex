defmodule PicselloWeb.GalleryLive.ClientShow do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"hash" => hash}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:hash, hash)
    }
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
end
