defmodule PicselloWeb.GalleryLive.GalleryProduct do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  import Ecto.Changeset
  import PicselloWeb.LiveHelpers
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.GalleryProducts

  @per_page 12

  @impl true
  def mount(
        %{"id" => gallery_id, "gallery_product_id" => gallery_product_id},
        _session,
        socket
      ) do
    case check_preview(%{:gallery_id => gallery_id, :id => gallery_product_id}) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      preview ->
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
             preview: preview_url(preview.preview_photo),
             ratio: get_in(preview, [:preview_photo, :aspect_ratio]),
             frame: frame,
             coords: coords,
             target: "canvas"
           })
         end)
         |> assign(:changeset, changeset(%{}, []))
         |> assign(:preview_photo_id, nil)}
    end
  end

  def check_preview(%{:gallery_id => gallery_id, :id => gallery_product_id}) do
    gallery = Galleries.get_gallery!(gallery_id)

    preview = GalleryProducts.get(%{id: gallery_product_id, gallery_id: gallery_id})

    if nil in [preview, gallery] do
      gallery == nil &&
        Logger.error("not found row with gallery_id: #{gallery_id} in galleries table")

      preview == nil &&
        Logger.error(
          "not found row with gallery_product_id: #{gallery_product_id} in galleries_product table"
        )

      nil
    else
      preview
    end
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
        socket
      ) do
    frame = Map.get(socket.assigns, :frame)
    coords = Map.get(socket.assigns, :coords)

    socket
    |> assign(:preview_photo_id, to_integer(preview_photo_id))
    |> assign(:preview, preview_url(preview))
    |> assign(:changeset, changeset(%{preview_photo_id: preview_photo_id}, [:preview_photo_id]))
    |> push_event("set_preview", %{
      preview: preview_url(preview),
      frame: frame,
      coords: coords,
      target: "canvas"
    })
    |> noreply
  end

  def handle_event(
        "save",
        %{"gallery_product" => %{"preview_photo_id" => preview_photo_id}},
        %{
          assigns: %{
            frame_id: frame_id,
            gallery_product_id: product_id,
            gallery: %{id: gallery_id}
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

      {:noreply, socket |> push_redirect(to: Routes.gallery_show_path(socket, :show, gallery_id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(%{"id" => id, "gallery_product_id" => gallery_product_id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    GalleryProducts.get(%{:id => to_integer(gallery_product_id)})
    |> case do
      nil ->
        {:noreply, redirect(socket, to: "/")}

      gallery_product ->
        socket
        |> assign(:title, gallery_product.category.name)
        |> assign(:gallery, gallery)
        |> assign(:gallery_product_id, gallery_product.id)
        |> assign(:page, 0)
        |> assign(:favorites_filter, false)
        |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
        |> assign_photos()
        |> noreply()
    end
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
    photos =
      Galleries.get_gallery_photos(id,
        only_favorites: filter,
        offset: per_page * page,
        limit: per_page + 1
      )

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, photos |> length > per_page)
  end
end
