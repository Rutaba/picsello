defmodule PicselloWeb.GalleryLive.ClientShow do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Galleries

  @per_page 12

  @impl true
  def handle_params(_params, _, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:page_title, "Show Gallery")
    |> assign(:products, Galleries.get_gallery_products(gallery.id))
    |> assign(:page, 0)
    |> assign(:update_mode, "append")
    |> assign(:favorites_filter, false)
    |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
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

  def handle_event("open_edit_product_popup", _, socket) do
    socket
    |> open_modal(PicselloWeb.GalleryLive.EditProduct, %{product: %{}})
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

  def handle_info(
        {:photo_click, photo},
        %{assigns: %{gallery: gallery, favorites_filter: favorites?}} = socket
      ) do
    created_editor =
      Picsello.WHCC.create_editor(
        get_some_product(),
        photo,
        # design: "SjhvrFtjMP7FHy6Qa",
        complete_url: Routes.gallery_dump_editor_url(socket, :show) <> "?editorId=%EDITOR_ID%",
        cancel_url: Routes.gallery_client_show_url(socket, :show, gallery.client_link_hash),
        only_favorites: favorites?
      )

    socket
    |> redirect(external: created_editor.url)
    |> noreply()
  end

  # This should be removed as soon as product selection will be implemented
  defp get_some_product() do
    Picsello.Category
    |> Picsello.Repo.all()
    |> Enum.at(0)
    |> Picsello.Repo.preload(:products)
    |> then(& &1.products)
    |> Enum.at(0)
  end

  def get_menu_items(_socket),
    do: [
      %{title: "Home", path: "#"},
      %{title: "Shop", path: "#"},
      %{title: "My orders", path: "#"},
      %{title: "Help", path: "#"}
    ]

  defp assign_photos(
         %{
           assigns: %{
             gallery: %{id: id},
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
    |> assign(:has_more_photos, photos |> length > per_page)
  end
end
