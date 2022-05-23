defmodule PicselloWeb.GalleryLive.ClientAlbum do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Repo, Galleries, Albums}
  alias Picsello.GalleryProducts
  alias Picsello.Cart
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
      # package: Galleries.get_package(gallery),
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
  def handle_event(
        "toggle_favorites",
        _,
        %{
          assigns: %{
            favorites_filter: favorites_filter
          }
        } = socket
      ) do
    toggle_state = !favorites_filter

    socket
    |> assign(:page, 0)
    |> assign(:favorites_filter, toggle_state)
    |> then(fn socket ->
      case toggle_state do
        true ->
          socket
          |> assign(:update_mode, "replace")

        _ ->
          socket
          |> assign(:update_mode, "append")
      end
    end)
    |> assign_photos(@per_page)
    |> push_event("reload_grid", %{})
    |> noreply()
  end

  def handle_event(
        "product_preview_photo_click",
        %{"params" => id},
        %{
          assigns: %{
            products: products
          }
        } = socket
      ) do
    gallery_product = Enum.find(products, fn product -> product.id == String.to_integer(id) end)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.EditProduct,
      %{
        category: gallery_product.category,
        photo: gallery_product.preview_photo
      }
    )
    |> noreply()
  end

  def handle_event(
        "product_preview_photo_click",
        %{"photo-id" => photo_id, "template-id" => template_id},
        socket
      ) do
    photo = Galleries.get_photo(photo_id)

    template_id = template_id |> to_integer()

    category =
      GalleryProducts.get(id: template_id)
      |> then(& &1.category)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.EditProduct,
      %{
        category: category,
        photo: photo
      }
    )
    |> noreply()
  end

  def handle_event(
        "click",
        %{"preview_photo_id" => photo_id},
        %{
          assigns: %{
            gallery: gallery,
            favorites_filter: favorites_filter
          }
        } = socket
      ) do
    photo_ids = Galleries.get_gallery_photo_ids(gallery.id, favorites_filter: favorites_filter)

    photo_id = to_integer(photo_id)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ChooseProduct,
      %{
        gallery: gallery,
        photo_id: photo_id,
        photo_ids:
          photo_ids
          |> CLL.init()
          |> CLL.next(Enum.find_index(photo_ids, &(&1 == photo_id)) || 0)
      }
    )
    |> noreply
  end

  def handle_info(
        {:customize_and_buy_product, whcc_product, photo, size},
        %{
          assigns: %{
            gallery: gallery,
            favorites_filter: favorites
          }
        } = socket
      ) do
    created_editor =
      Picsello.WHCC.create_editor(
        whcc_product,
        photo,
        complete_url:
          Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
            "?editorId=%EDITOR_ID%",
        secondary_url:
          Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash) <>
            "?editorId=%EDITOR_ID%&clone=true",
        cancel_url: Routes.gallery_client_index_url(socket, :index, gallery.client_link_hash),
        size: size,
        favorites_only: favorites
      )

    socket
    |> redirect(external: created_editor.url)
    |> noreply()
  end
end
