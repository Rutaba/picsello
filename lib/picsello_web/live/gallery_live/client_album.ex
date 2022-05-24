defmodule PicselloWeb.GalleryLive.ClientAlbum do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Repo, Galleries, GalleryProducts, Albums, Cart}
  alias PicselloWeb.GalleryLive.Photos.Photo

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      photo_updates: "false",
      download_all_visible: false
    )
    |> ok()
  end

  @impl true
  def handle_params(
        %{"album_id" => album_id},
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    gallery = Galleries.populate_organization_user(gallery)
    album = Albums.get_album!(album_id) |> Repo.preload(:photos)

    socket
    |> assign(
      favorites_count: Galleries.gallery_favorites_count(gallery),
      favorites_filter: false,
      gallery: gallery,
      album: album,
      page: 0,
      page_title: "Show Album",
      download_all_visible: Cart.can_download_all?(gallery),
      products: GalleryProducts.get_gallery_products(gallery.id),
      update_mode: "append"
    )
    |> assign_cart_count(gallery)
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event(
        "load-more",
        _,
        %{
          assigns: %{
            page: page
          }
        } = socket
      ) do
    socket
    |> assign(page: page + 1)
    |> assign_photos(@per_page)
    |> noreply()
  end

  @impl true
  def handle_event("toggle_favorites", _, socket) do
    socket |> toggle_favorites(@per_page)
  end

  @impl true
  def handle_event("product_preview_photo_popup", %{"params" => product_id}, socket) do
    socket |> product_preview_photo_popup(product_id)
  end

  @impl true
  def handle_event(
        "product_preview_photo_popup",
        %{"photo-id" => photo_id, "template-id" => template_id},
        socket
      ) do
    socket |> product_preview_photo_popup(photo_id, template_id)
  end

  @impl true
  def handle_event("click", %{"preview_photo_id" => photo_id}, socket) do
    socket |> client_photo_click(photo_id)
  end

  def handle_info({:customize_and_buy_product, whcc_product, photo, size}, socket) do
    socket |> customize_and_buy_product(whcc_product, photo, size)
  end

  def handle_info(
    {:add_digital_to_cart, digital},
    %{assigns: %{gallery: gallery}} = socket
  ) do
    order = Cart.place_product(digital, gallery.id)

    socket |> assign(order: order) |> assign_cart_count(gallery) |> close_modal() |> noreply()
  end

  def handle_info(
      {:add_bundle_to_cart, bundle_price},
      %{assigns: %{gallery: gallery}} = socket
    ) do
    order = Cart.place_product({:bundle, bundle_price}, gallery.id)

    socket |> assign(order: order) |> assign_cart_count(gallery) |> close_modal() |> noreply()
  end
end
