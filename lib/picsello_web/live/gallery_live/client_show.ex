defmodule PicselloWeb.GalleryLive.ClientShow do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries

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
      |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
      |> assign_photos()
      |> noreply()
    else
      {:noreply, socket}
    end
  end

  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    IO.inspect socket
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, %{assigns: %{favorites_filter: toggle_state}} = socket) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_info(:increase_favorites_count, %{assigns: %{favorites_count: count}} = socket) do
    socket |> assign(:count, count + 1) |> noreply()
  end

  @impl true
  def handle_info(:reduce_favorites_count, %{assigns: %{favorites_count: count}} = socket) do
    socket |> assign(:count, count - 1) |> noreply()
  end

  defp assign_photos(
         %{assigns: %{gallery: %{id: id}, page: page, favorites_filter: filter}} = socket
       ) do
    assign(socket,
      photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
    )
  end
end
