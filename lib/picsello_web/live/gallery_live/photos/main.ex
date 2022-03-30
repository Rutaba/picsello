defmodule PicselloWeb.GalleryLive.Photos.Main do
  @moduledoc false
  use PicselloWeb,
    live_view: [
      layout: "live_client"
    ]

  alias Picsello.Repo
  alias Picsello.Galleries

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    gallery = Galleries.get_gallery!(id) |> Repo.preload(:albums)

    socket
    |> assign(
      gallery_id: id,
      favorites_filter: false,
      gallery: gallery,
      page: 0,
      page_title: page_title(socket.assigns.live_action),
      products: Galleries.products(gallery)
    )
    |> assign_photos()
    |> noreply()
  end

  @impl true
  def handle_info(
        {:save, %{preview_photo_id: preview_photo_id, frame_id: frame_id, title: title}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> assign(products: Galleries.products(gallery))
    |> close_modal()
    |> put_flash(:photo_success, "#{title} preview successfully updated")
    |> noreply
  end

  @impl true
  def handle_event(
        "edit_product",
        %{"category_id" => gallery_product_id},
        %{assigns: %{gallery_id: gallery_id}} = socket
      ) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.Photos.EditProduct,
      %{gallery_product_id: gallery_product_id, gallery_id: gallery_id}
    )
    |> noreply
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
    opts = [only_favorites: filter, exclude_album: true, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(
      :photos,
      photos
      |> Enum.take(per_page)
    )
    |> assign(
      :has_more_photos,
      photos
      |> length > per_page
    )
  end

  defp page_title(:show), do: "Show Gallery"
  defp page_title(:edit), do: "Edit Gallery"
  defp page_title(:upload), do: "New Gallery"
end
