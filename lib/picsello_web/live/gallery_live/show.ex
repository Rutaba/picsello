defmodule PicselloWeb.GalleryLive.Show do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:gallery, Galleries.get_gallery!(id))
     |> assign(:photos, Galleries.get_gallery_photos(id, 12, 0))}
  end

  def handle_event("add_page", _, %{assigns: %{gallery: %{id: id}}} = socket) do
    socket
    |> assign(:photos, Galleries.get_gallery_photos(id, 12, 1))
    |> noreply()
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
end
