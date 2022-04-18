defmodule PicselloWeb.GalleryLive.Photos.PhotoPreview do
  @moduledoc "Component to set product preview from photos"

  use PicselloWeb, :live_component
  require Logger
  import Ecto.Changeset
  import PicselloWeb.LiveHelpers

  alias Picsello.{Repo, Galleries, GalleryProducts}

  @impl true
  def update(%{gallery: gallery, photo_id: photo_id}, socket) do
    photo = Galleries.get_photo(photo_id)

    products = GalleryProducts.get_gallery_products(gallery.id, :with_or_without_previews)

    socket
    |> assign(:changeset, changeset(%{}, []))
    |> assign(:preview_photo_id, nil)
    |> assign(
      gallery_id: gallery.id,
      selected: [],
      photo: photo,
      products: products,
      url: path(photo.watermarked_preview_url || photo.preview_url)
    )
    |> ok()
  end

  @impl true
  def handle_event(
        "click",
        %{"product" => product_id},
        %{
          assigns: %{
            selected: selected,
            photo: photo,
            url: url,
            products: products
          }
        } = socket
      ) do
    [preview | _] =
      Enum.filter(products, fn product ->
        product.id == String.to_integer(product_id)
      end)

    frame = Picsello.Category.frame_image(preview.category)
    coords = Picsello.Category.coords(preview.category)

    selected =
      if Enum.member?(selected, product_id) do
        List.delete(selected, product_id)
      else
        [product_id | selected]
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
      target: product_id
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
            products: products,
            gallery_id: gallery_id
          }
        } = socket
      ) do
    Enum.each(selected, fn product_id ->
      [preview | _] =
        Enum.filter(products, fn product ->
          product.id == String.to_integer(product_id)
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
    |> put_flash(:gallery_success, "Photo preview successfully created")
    |> noreply
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.GalleryProduct{}, data, prop)
    |> validate_required([])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col bg-white p-10 rounded-lg">
      <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="text-3xl font-bold font-sans">
            Set as preview for which products?
          </h1>
          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-2 h-2 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
      </div>
      <div class="font-sans flex bg-white py-10 relative">
          <div id="product-preview" class="grid grid-cols-3 gap-4 items-center" phx-hook="Preview">
              <%= for product <- @products do %>
              <div class="items-center">
                <div
                id={"product-#{product.id}"}
                class="font-sans flex h-52 w-52 p-6 bg-gray-100 text-black"
                phx-click="click" phx-target={@myself}
                phx-value-product={product.id}
                >
                  <img
                  id={"img-#{product.id}"}
                  src={Routes.static_path(PicselloWeb.Endpoint, "/images/#{product.category.frame_image}")}
                  class="mx-auto bg-gray-300 items-center cursor-pointer"/>
                  <div id={"preview-#{product.id}"} class="flex justify-center row-span-2 previewImg">
                      <canvas id={"canvas-#{product.id}"} width="300" height="255" class="edit"></canvas>
                  </div>
                </div>
                <div class="font-sans fomt-bold pt-4 flex items-center">
                  <%= product.category.name %>
                </div>
              </div>
              <% end %>
          </div>
      </div>
      <div class="flex font-sans flex-row items-center justify-end w-full lg:items-start">
          <button
          phx-click="modal"
          phx-value-action="close"
          title="close modal"
          class="mr-3 py-2 px-6 float-right rounded-lg border bg-white border-black"
          >
            Cancel
          </button>
          <button
          phx-click="save"
          phx-target={@myself}
          aria-label="save"
          class="py-2 px-6 float-right rounded-lg bg-black text-white"
          >
            Save changes
          </button>
      </div>
    </div>
    """
  end
end
