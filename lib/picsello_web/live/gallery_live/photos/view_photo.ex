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
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defdelegate min_price(category), to: Picsello.WHCC
end
