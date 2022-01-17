defmodule PicselloWeb.GalleryLive.ChooseProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers
  alias Picsello.{Galleries, CategoryTemplate}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id, photo_ids: photo_ids}, socket) do
    photo = Galleries.get_photo(photo_id)
    templates = CategoryTemplate.all_with_gallery_products(gallery.id)

    socket
    |> assign(:gallery_id, gallery.id)
    |> assign(:templates, templates)
    |> assign(:photo_client_liked, photo.client_liked)
    |> assign(:url, path(photo.watermarked_preview_url || photo.preview_url))
    |> assign(:photo_ids, photo_ids)
    |> assign(:photo_id, photo.id)
    |> ok
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
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end
end
