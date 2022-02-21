defmodule PicselloWeb.GalleryLive.ClientShow do
  @moduledoc false

  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  import PicselloWeb.GalleryLive.Shared

  alias Phoenix.PubSub
  alias Picsello.Galleries
  alias Picsello.GalleryProducts
  alias Picsello.Cart

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:photo_updates, "false")
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

    if connected?(socket) do
      PubSub.subscribe(Picsello.PubSub, "gallery:#{gallery.id}")
    end

    socket
    |> assign(:gallery, gallery)
    |> assign(:page_title, "Show Gallery")
    |> assign(:products, GalleryProducts.get_gallery_products(gallery.id))
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_cart_count(gallery)
    |> assign_photos()
    |> assign(:creator, Galleries.get_gallery_creator(gallery))
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
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle_favorites",
        _,
        %{
          assigns: %{
            favorites_filter: toggle_state
          }
        } = socket
      ) do
    socket
    |> assign(:page, 0)
    |> assign(:update_mode, "replace")
    |> assign(:favorites_filter, !toggle_state)
    |> assign_photos()
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
        %{"photo_id" => photo_id, "template_id" => template_id},
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

  @impl true
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
    photo_ids =
      Galleries.get_photo_ids(gallery_id: gallery.id, favorites_filter: favorites_filter)

    socket
    |> open_modal(
      PicselloWeb.GalleryLive.ChooseProduct,
      %{
        gallery: gallery,
        photo_id: photo_id,
        photo_ids:
          CLL.init(photo_ids)
          |> CLL.next(Enum.find_index(photo_ids, &(&1 == to_integer(photo_id))) || 0)
      }
    )
    |> noreply
  end

  @impl true
  def handle_info(
        :increase_favorites_count,
        %{
          assigns: %{
            favorites_count: count
          }
        } = socket
      ) do
    socket
    |> assign(:count, count + 1)
    |> noreply()
  end

  @impl true
  def handle_info(
        :reduce_favorites_count,
        %{
          assigns: %{
            favorites_count: count
          }
        } = socket
      ) do
    socket
    |> assign(:count, count - 1)
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
          Routes.gallery_client_show_url(socket, :show, gallery.client_link_hash) <>
            "?editorId=%EDITOR_ID%",
        cancel_url: Routes.gallery_client_show_url(socket, :show, gallery.client_link_hash),
        size: size,
        favorites_only: favorites
      )

    socket
    |> redirect(external: created_editor.url)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:photo_processed, _, photo},
        socket
      ) do
    photo_update =
      %{
        id: photo.id,
        url: display_photo(photo.watermarked_preview_url || photo.preview_url)
      }
      |> Jason.encode!()

    socket
    |> assign(:photo_updates, photo_update)
    |> noreply()
  end

  def handle_info({:cover_photo_processed, _, _}, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(
      :gallery,
      gallery.id
      |> Galleries.get_gallery!()
      |> Galleries.populate_organization_user()
    )
    |> noreply()
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

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{
               id: id
             },
             page: page,
             favorites_filter: filter
           }
         } = socket,
         per_page \\ @per_page
       ) do
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, length(photos) > per_page)
  end
end
