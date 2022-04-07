defmodule PicselloWeb.GalleryLive.ProductPreview.EditProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers

  import Ecto.Changeset
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.GalleryProducts

  @per_page 24

  @impl true
  def preload([assigns | _]) do
    %{gallery_id: gallery_id, product_id: product_id} = assigns

    gallery = Galleries.get_gallery!(gallery_id)
    product = GalleryProducts.get(%{:id => to_integer(product_id)})
    preview = GalleryProducts.get(%{id: product_id, gallery_id: gallery_id})

    [
      Map.merge(assigns, %{
        gallery: gallery,
        product: product,
        preview: preview,
        favorites_count: Galleries.gallery_favorites_count(gallery),
        frame: Picsello.Category.frame_image(preview.category),
        coords: Picsello.Category.coords(preview.category),
        frame_id: preview.category.id,
        category_id: preview.category.id,
        title: "#{product.category.name} preview"
      })
    ]
  end

  @impl true
  def update(
        %{
          preview: preview,
          frame: frame,
          coords: coords
        } = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)
     |> then(fn socket ->
       push_event(socket, "set_preview", %{
         preview: get_preview(preview),
         ratio: get_in(preview, [:preview_photo, :aspect_ratio]),
         frame: frame,
         coords: coords,
         target: "#{preview.category.id}-edit"
       })
     end)
     |> assign(
       :description,
       "Select one of your gallery photos that best showcases this product - your client will use this as a starting point, and can customize their product further in the editor."
     )
     |> assign(:page_title, "Product Preview")
     |> assign(:page, 0)
     |> assign(:favorites_filter, false)
     |> assign(:preview_photo_id, nil)
     |> assign(:selected, false)
     |> assign_photos()}
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign_photos()
    |> noreply()
  end

  def handle_event(
        "click",
        %{"preview" => preview, "preview_photo_id" => preview_photo_id},
        %{assigns: %{category_id: category_id}} = socket
      ) do
    frame = Map.get(socket.assigns, :frame)
    coords = Map.get(socket.assigns, :coords)

    socket
    |> assign(:preview_photo_id, to_integer(preview_photo_id))
    |> assign(:selected, true)
    |> assign(:preview, path(preview))
    |> push_event("set_preview", %{
      preview: path(preview),
      frame: frame,
      coords: coords,
      target: "#{category_id}-edit"
    })
    |> noreply
  end

  def handle_event(
        "save",
        _,
        %{
          assigns: %{
            preview_photo_id: preview_photo_id,
            frame_id: frame_id,
            product_id: product_id,
            gallery: %{id: gallery_id},
            title: title
          }
        } = socket
      ) do
    [frame_id, preview_photo_id, product_id, gallery_id] =
      Enum.map(
        [frame_id, preview_photo_id, product_id, gallery_id],
        fn x -> to_integer(x) end
      )

    result =
      GalleryProducts.get(%{
        id: to_integer(product_id),
        gallery_id: to_integer(gallery_id)
      })

    if result != nil do
      result
      |> cast(%{preview_photo_id: preview_photo_id, category_id: frame_id}, [
        :preview_photo_id,
        :category_id
      ])
      |> Repo.insert_or_update()

      send(
        self(),
        {:save, %{preview_photo_id: preview_photo_id, frame_id: frame_id, title: title}}
      )
    end

    {:noreply, socket}
  end

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

  def get_preview(%{preview_photo: %{preview_url: url}}), do: path(url)
  def get_preview(_), do: path(nil)
end
