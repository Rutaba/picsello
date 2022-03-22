defmodule PicselloWeb.GalleryLive.Photos.ProductPreview do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers
  alias Picsello.{Galleries, GalleryProducts}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id}, socket) do
    photo = Galleries.get_photo(photo_id)
    product_categories = GalleryProducts.get_gallery_product_categories(gallery.id)

    socket
    |> assign(
      gallery_id: gallery.id,
      photo: photo,
      product_categories: product_categories,
      url: path(photo.watermarked_preview_url || photo.preview_url)
    )
    |> ok()
  end
end
