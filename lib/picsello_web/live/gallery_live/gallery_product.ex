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
        %{"id" => gallery_id, "gallery_product_id" => gallery_product_id} = params,
        _session,
        socket
      ) do
    case check_preview(%{:gallery_id => gallery_id, :id => gallery_product_id}) do
      nil ->
        {:ok, redirect(socket, to: "/")}

      preview ->
        template = preview.category_template

        url = get_preview(preview)

        {frame_id, frame_name, coords} =
          with id when id != nil <- params["frame_id"],
               templ when templ != nil <- Repo.get(Picsello.CategoryTemplate, id) do
            templ
          else
            _ -> template
          end
          |> then(fn x -> {x.id, x.name, x.corners} end)

        {:ok,
         socket
         |> assign(:frame_id, frame_id)
         |> assign(:frame, frame_name)
         |> assign(:coords, inspect(coords))
         |> assign(:preview, preview)
         |> push_event("set_preview", %{
           preview: url,
           frame: frame_name,
           coords: coords,
           target: "canvas"
         })
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
    |> assign(:preview, path(preview))
    |> assign(:changeset, changeset(%{preview_photo_id: preview_photo_id}, [:preview_photo_id]))
    |> push_event("set_preview", %{
      preview: path(preview),
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
      |> cast(%{preview_photo_id: preview_photo_id, category_template_id: frame_id}, [
        :preview_photo_id,
        :category_template_id
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

    if GalleryProducts.get(%{:id => to_integer(gallery_product_id)}) == nil do
      {:noreply, redirect(socket, to: "/")}
    else
      socket
      |> assign(:gallery, gallery)
      |> assign(:gallery_product_id, gallery_product_id)
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
    opts = [only_favorites: filter, offset: per_page * page]
    photos = Galleries.get_gallery_photos(id, per_page + 1, page, opts)

    socket
    |> assign(:photos, photos |> Enum.take(per_page))
    |> assign(:has_more_photos, photos |> length > per_page)
  end

  def get_preview(%{preview_photo: %{preview_url: url}}), do: path(url)
  def get_preview(_), do: path(nil)
end
