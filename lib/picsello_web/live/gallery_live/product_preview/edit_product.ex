defmodule PicselloWeb.GalleryLive.ProductPreview.EditProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers
  import Ecto.Changeset
  import PicselloWeb.LiveHelpers
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.GalleryProducts

  @per_page 12

  @impl true
  def update(
        %{gallery_id: gallery_id, product_id: product_id},
        socket
      ) do
    gallery = Galleries.get_gallery!(gallery_id)
    product = GalleryProducts.get(%{:id => to_integer(product_id)})
    # ToDO: need to optimize
    preview = check_preview(%{:gallery_id => gallery_id, :product_id => product_id})

    {:ok,
     socket
     |> assign(
       frame_id: preview.category.id,
       frame: Picsello.Category.frame_image(preview.category),
       coords: Picsello.Category.coords(preview.category),
       preview: preview
     )
     |> then(fn %{assigns: %{coords: coords, frame: frame}} = socket ->
       push_event(socket, "set_preview", %{
         preview: get_preview(preview),
         ratio: get_in(preview, [:preview_photo, :aspect_ratio]),
         frame: frame,
         coords: coords,
         target: "#{preview.category.id}-edit"
       })
     end)
     |> assign(:title, product.category.name)
     |> assign(:product_id, product.id)
     |> assign(:page, 0)
     |> assign(:favorites_filter, false)
     |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
     |> assign(:changeset, changeset(%{}, []))
     |> assign(:gallery, gallery)
     |> assign(:category_id, preview.category.id)
     |> assign_photos()
     |> assign(:preview_photo_id, nil)}
  end

  def check_preview(%{:gallery_id => gallery_id, :product_id => product_id}) do
    preview = GalleryProducts.get(%{id: product_id, gallery_id: gallery_id})
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleryProduct{}, data, prop)
    |> validate_required([])
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
    |> assign(:preview, path(preview))
    |> assign(:changeset, changeset(%{preview_photo_id: preview_photo_id}, [:preview_photo_id]))
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
        %{"gallery_product" => %{"preview_photo_id" => preview_photo_id}},
        %{
          assigns: %{
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
