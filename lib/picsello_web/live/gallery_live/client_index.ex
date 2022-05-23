defmodule PicselloWeb.GalleryLive.ClientIndex do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Galleries, Albums}
  alias Picsello.GalleryProducts
  alias Picsello.Cart
  alias PicselloWeb.GalleryLive.Photos.Photo

  @per_page 12
  @max_age 7
  @cover_photo_cookie "_picsello_web_gallery"
  @blank_image "/images/album_placeholder.png"

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      photo_updates: "false",
      download_all_visible: false,
      active: false
    )
    |> ok()
  end

  @impl true
  def handle_params(
        %{"editorId" => whcc_editor_id},
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    socket
    |> place_product_in_cart(whcc_editor_id)
    |> push_redirect(
      to: Routes.gallery_client_show_cart_path(socket, :cart, gallery.client_link_hash)
    )
    |> noreply()
  end

  @impl true
  def handle_params(
        _params,
        _,
        %{
          assigns: %{
            gallery: gallery
          }
        } = socket
      ) do
    gallery = Galleries.populate_organization_user(gallery)

    socket
    |> assign(
      creator: Galleries.get_gallery_creator(gallery),
      package: Galleries.get_package(gallery),
      favorites_count: Galleries.gallery_favorites_count(gallery),
      favorites_filter: false,
      gallery: gallery,
      albums: Albums.get_albums_by_gallery_id(gallery.id),
      page: 0,
      page_title: "Show Gallery",
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

  @impl true
  def handle_event("view_gallery", _, socket) do
    socket
    |> push_event("reload_grid", %{})
    |> assign(:active, true)
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

  def handle_event("buy-all-digitals", _, socket) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.ChooseBundle, Map.take(socket.assigns, [:gallery]))
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

  @impl true
  def handle_event(
        "go_to_album",
        %{"album" => album_id},
        %{
          assigns: %{
            gallery: %{
              client_link_hash: client_link_hash
            }
          }
        } = socket
      ) do
    socket
    |> push_redirect(
      to: Routes.gallery_client_album_path(socket, :album, client_link_hash, album_id)
    )
    |> noreply()
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

  defp place_product_in_cart(
         %{
           assigns: %{
             gallery: gallery
           }
         } = socket,
         whcc_editor_id
       ) do
    gallery_account_id = Galleries.account_id(gallery)
    cart_product = Cart.new_product(whcc_editor_id, gallery_account_id)
    Cart.place_product(cart_product, gallery.id)

    socket
  end

  defp cover_photo(%{cover_photo: nil}), do: %{style: "background-image: url('#{@blank_image}')"}
  defp cover_photo(gallery), do: display_cover_photo(gallery)

  defp photos_count(nil), do: "photo"
  defp photos_count(count), do: "#{count} #{ngettext("photo", "photos", count)}"
  defp max_age, do: @max_age
  defp cover_photo_cookie(gallery_id), do: "#{@cover_photo_cookie}_#{gallery_id}"

  defp thumbnail_url(%{thumbnail_photo: nil}), do: @blank_image
  defp thumbnail_url(%{thumbnail_photo: photo}), do: preview_url(photo)
end
