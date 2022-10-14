defmodule PicselloWeb.GalleryLive.ClientIndex do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_gallery_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{
    Galleries,
    Albums,
    Cart,
    GalleryProducts,
    Orders
  }

  alias PicselloWeb.GalleryLive.Photos.Photo
  alias PicselloWeb.GalleryLive.Shared.DownloadLinkComponent

  @per_page 12
  @max_age 7
  @cover_photo_cookie "_picsello_web_gallery"
  @blank_image "/images/album_placeholder.png"

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    if connected?(socket), do: Galleries.subscribe(gallery)

    socket
    |> assign(
      photo_updates: "false",
      download_all_visible: false,
      active: false,
      credits: credits(gallery)
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
      albums: get_albums(gallery.id),
      page: 0,
      page_title: gallery.name,
      download_all_visible: Orders.can_download_all?(gallery),
      products: GalleryProducts.get_gallery_products(gallery.id, :coming_soon_false),
      update_mode: "append"
    )
    |> assign_cart_count(gallery)
    |> assign_photo_count()
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
    |> assign(:update_mode, "append")
    |> assign(page: page + 1)
    |> assign_photos(@per_page)
    |> noreply()
  end

  def handle_event("toggle_favorites", _, socket) do
    socket
    |> case do
      %{assigns: %{favorites_filter: false, favorites_count: favorites_count}} = socket ->
        assign(socket, photos_count: favorites_count)

      socket ->
        assign_photo_count(socket)
    end
    |> toggle_favorites(@per_page)
  end

  def handle_event("view_gallery", _, socket) do
    socket
    |> push_event("reload_grid", %{})
    |> assign(:active, true)
    |> noreply()
  end

  def handle_event("product_preview_photo_popup", %{"params" => product_id}, socket) do
    socket |> product_preview_photo_popup(product_id)
  end

  def handle_event(
        "product_preview_photo_popup",
        %{"photo-id" => photo_id, "template-id" => template_id},
        socket
      ) do
    socket |> product_preview_photo_popup(photo_id, template_id)
  end

  def handle_event("buy-all-digitals", _, socket) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.ChooseBundle, Map.take(socket.assigns, [:gallery]))
    |> noreply()
  end

  def handle_event("click", %{"preview_photo_id" => photo_id}, socket) do
    socket |> client_photo_click(photo_id)
  end

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
        %{assigns: %{favorites_filter: favorites_only}} = socket
      ) do
    socket
    |> customize_and_buy_product(whcc_product, photo, size: size, favorites_only: favorites_only)
  end

  def handle_info(
        {:add_digital_to_cart, digital, _finals_album_id},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Cart.place_product(digital, gallery.id)
    socket |> add_to_cart_assigns(order)
  end

  def handle_info(
        {:add_bundle_to_cart, bundle_price},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Cart.place_product({:bundle, bundle_price}, gallery.id)
    socket |> add_to_cart_assigns(order)
  end

  def handle_info({:open_choose_product, photo_id}, socket) do
    socket |> client_photo_click(photo_id)
  end

  def handle_info({:pack, :ok, %{packable: %{id: packable_id}, status: status}}, socket) do
    DownloadLinkComponent.update_status(packable_id, status)

    noreply(socket)
  end

  def handle_info({:pack, _, _}, socket), do: noreply(socket)
  def handle_info({:upload_success_message, _}, socket), do: noreply(socket)
  def handle_info({:photo_processed, _, _}, socket), do: noreply(socket)

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

  defp assign_photo_count(
         %{
           assigns: %{
             gallery: %{
               id: id,
               total_count: total_count
             },
             albums: albums
           }
         } = socket
       ) do
    photos_count =
      case Enum.count(albums) do
        0 -> total_count
        _ -> Galleries.get_albums_photo_count(id)
      end

    socket
    |> assign(photos_count: photos_count)
  end

  defp get_albums(id) do
    id
    |> Albums.get_albums_by_gallery_id()
    |> Picsello.Repo.preload(:photos)
    |> Enum.filter(&(Enum.count(&1.photos) > 0 && !&1.is_proofing && !&1.is_finals))
  end

  defdelegate download_link(assigns), to: DownloadLinkComponent
end
