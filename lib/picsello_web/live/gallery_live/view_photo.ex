defmodule PicselloWeb.GalleryLive.ViewPhoto do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers
  alias Picsello.{Galleries, GalleryProducts}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id, photo_ids: photo_ids}, socket) do
    photo = Galleries.get_photo(photo_id)
    products = GalleryProducts.get_gallery_products(gallery.id)

    socket
    |> assign(
         gallery_id: gallery.id,
         photo_client_liked: photo.client_liked,
         photo_id: photo.id,
         photo_ids: photo_ids,
         products: products,
         url: path(photo.watermarked_preview_url || photo.preview_url)
       )
    |> ok()
  end

  @impl true
  def handle_event("prev", _, %{assigns: %{photo_ids: photo_ids}} = socket) do
    photo_ids = CLL.prev(photo_ids)
    photo_id = CLL.value(photo_ids)
    photo = Galleries.get_photo(photo_id)

    socket
    |> assign(:url, path(photo.watermarked_preview_url || photo.preview_url))
    |> assign(:photo_id, photo_id)
    |> assign(:photo_ids, photo_ids)
    |> assign(:photo_client_liked, photo.client_liked)
    |> noreply
  end

  @impl true
  def handle_event("next", _, %{assigns: %{photo_ids: photo_ids}} = socket) do
    photo_ids = CLL.next(photo_ids)
    photo_id = CLL.value(photo_ids)
    photo = Galleries.get_photo(photo_id)

    socket
    |> assign(:url, path(photo.watermarked_preview_url || photo.preview_url))
    |> assign(:photo_id, photo_id)
    |> assign(:photo_ids, photo_ids)
    |> assign(:photo_client_liked, photo.client_liked)
    |> noreply
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowLeft"}, socket),
      do: __MODULE__.handle_event("prev", [], socket)

  @impl true
  def handle_event("keydown", %{"key" => "ArrowRight"}, socket),
      do: __MODULE__.handle_event("next", [], socket)

  @impl true
  def handle_event("keydown", _, socket), do: socket |> noreply

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defdelegate min_price(category), to: Picsello.WHCC
end
