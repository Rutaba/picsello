defmodule PicselloWeb.GalleryLive.GalleryProduct do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  import Ecto.Changeset
  import PicselloWeb.LiveHelpers
  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Galleries.Workers.PhotoStorage

  @per_page 12

  @impl true
  def mount(%{"id" => gallery_id, "gallery_product_id" => gallery_product_id}, _session, socket) do
    gallery = Repo.get_by(Gallery, %{id: gallery_id})

    preview =
      Repo.get_by(GalleryProduct, %{
        :gallery_id => gallery_id,
        :id => to_integer(gallery_product_id)
      })
      |> Repo.preload([:preview_photo, :category_template])

    if nil in [preview, gallery] do
      gallery == nil &&
        Logger.error("not found row with gallery_id: #{gallery_id} in galleries table")

      preview == nil &&
        Logger.error(
          "not found row with gallery_product_id: #{gallery_product_id} in galleries_product table"
        )

      {:ok, redirect(socket, to: "/")}
    else
      url = preview.preview_photo.preview_url || nil
      frame = preview.category_template.name || nil
      frame_corners = preview.category_template.corners || nil

      {:ok,
       socket
       |> assign(:frame, frame)
       |> assign(:preview, path(url))
       |> assign(:frame_corners, "#{inspect(frame_corners)}")
       |> assign(:changeset, changeset(%{}, []))
       |> assign(:preview_photo_id, nil)}
    end
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleryProduct{}, data, prop)
    |> validate_required([:preview_photo_id])
  end

  @impl true
  def handle_event("load-more", _, %{assigns: %{page: page}} = socket) do
    socket
    |> assign(page: page + 1)
    |> assign(:update_mode, "append")
    |> assign_photos()
    |> noreply()
  end

  def handle_event(
        "set_preview",
        %{"preview" => preview, "preview_photo_id" => preview_photo_id},
        socket
      ) do
    socket
    |> assign(:preview_photo_id, to_integer(preview_photo_id))
    |> assign(:preview, path(preview))
    |> assign(:changeset, changeset(%{preview_photo_id: preview_photo_id}, [:preview_photo_id]))
    |> push_event("set_preview", %{preview: path(preview)})
    |> noreply
  end

  def handle_event(
        "save",
        %{"gallery_product" => %{"preview_photo_id" => preview_photo_id}},
        %{assigns: %{gallery_product_id: product_id, gallery: %{id: gallery_id}}} = socket
      ) do
    [preview_photo_id, product_id, gallery_id] =
      Enum.map(
        [preview_photo_id, product_id, gallery_id],
        fn x -> to_integer(x) end
      )

    fields = %{gallery_id: gallery_id, id: product_id}

    result = Repo.get_by(GalleryProduct, fields)

    if result != nil do
      result
      |> cast(%{preview_photo_id: preview_photo_id}, [:preview_photo_id])
      |> Repo.insert_or_update()
    end

    {:noreply, socket}
  end

  @impl true
  def handle_params(%{"id" => id, "gallery_product_id" => gallery_product_id}, _, socket) do
    gallery = Galleries.get_gallery!(id)

    if Repo.get_by(GalleryProduct, %{:id => to_integer(gallery_product_id)}) == nil do
      {:noreply, redirect(socket, to: "/")}
    else
      socket
      |> assign(:gallery, gallery)
      |> assign(:gallery_product_id, gallery_product_id)
      |> assign(:page, 0)
      |> assign(:update_mode, "append")
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

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
