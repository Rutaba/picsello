defmodule PicselloWeb.GalleryLive.ClientShow do
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries
  alias Picsello.Repo

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"hash" => hash}, _, socket) do
    gallery = Galleries.get_detailed_gallery_by_hash(hash)
    
    if gallery do
      socket
      |> assign(:hash, hash)
      |> assign(:gallery, gallery)
      |> assign(:page_title, "Show Gallery")
      |> assign(:page, 0)
      |> assign(:update_mode, "append")
      |> assign(:favorites_filter, false)
      |> assign_photos()
      |> noreply()
    else
      {:noreply, socket}
    end
  end

  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end
  
  def handle_event("toggle_favorites", _, %{assigns: %{favorites_filter: toggle_state}} = socket) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
    |> noreply()
  end

  defp assign_photos(%{assigns: %{gallery: %{id: id}, page: page, favorites_filter: filter}} = socket) do
    assign(socket, photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter))
  end
end
