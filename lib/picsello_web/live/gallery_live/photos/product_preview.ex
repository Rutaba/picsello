defmodule PicselloWeb.GalleryLive.Photos.ProductPreview do
  @moduledoc "no doc"
  use PicselloWeb, :live_component
  require Logger
  import Ecto.Changeset
  import PicselloWeb.LiveHelpers
  alias Picsello.Repo
  alias Picsello.{Galleries, GalleryProducts}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id}, socket) do
    photo = Galleries.get_photo(photo_id)

    product_categories =
      GalleryProducts.get_gallery_products(gallery.id, :with_or_without_previews)

    socket
    |> assign(:changeset, changeset(%{}, []))
    |> assign(:preview_photo_id, nil)
    |> assign(
      gallery_id: gallery.id,
      selected: [],
      photo: photo,
      product_categories: product_categories,
      url: path(photo.watermarked_preview_url || photo.preview_url)
    )
    |> ok()
  end

  @impl true
  def handle_event(
        "click",
        %{"category" => product_category_id},
        %{
          assigns: %{
            selected: selected,
            photo: photo,
            url: url,
            product_categories: product_categories
          }
        } = socket
      ) do
    [preview | _] =
      Enum.filter(product_categories, fn category ->
        category.id == String.to_integer(product_category_id)
      end)

    frame = Picsello.Category.frame_image(preview.category)
    coords = Picsello.Category.coords(preview.category)

    selected =
      if Enum.member?(selected, product_category_id) do
        List.delete(selected, product_category_id)
      else
        [product_category_id | selected]
      end

    socket
    |> assign(:preview_photo_id, to_integer(photo.id))
    |> assign(:preview, url)
    |> assign(:selected, selected)
    |> assign(:changeset, changeset(%{preview_photo_id: photo.id}, [:preview_photo_id]))
    |> push_event("set_preview", %{
      preview: url,
      frame: frame,
      coords: coords,
      target: product_category_id
    })
    |> noreply
  end

  @impl true
  def handle_event(
        "save",
        _,
        %{
          assigns: %{
            selected: selected,
            photo: photo,
            product_categories: product_categories,
            gallery_id: gallery_id
          }
        } = socket
      ) do
    Enum.each(selected, fn product_id ->
      [preview | _] =
        Enum.filter(product_categories, fn category ->
          category.id == String.to_integer(product_id)
        end)

      result =
        GalleryProducts.get(%{
          id: to_integer(preview.id),
          gallery_id: to_integer(gallery_id)
        })

      if result != nil do
        result
        |> cast(%{preview_photo_id: photo.id, category_id: preview.category.id}, [
          :preview_photo_id,
          :category_id
        ])
        |> Repo.insert_or_update()
      end
    end)

    socket
    |> close_modal()
    |> put_flash(:photo_success, "Photo preview successfully created")
    |> noreply
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleryProduct{}, data, prop)
    |> validate_required([])
  end
end
