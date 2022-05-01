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
    |> assign(
      changeset: changeset(%{}, []),
      gallery_id: gallery.id,
      selected: [],
      photo: photo,
      products: products,
      updated_products: products,
      selected_preview: Enum.reduce(products, %{}, &Map.merge(&2, %{&1.id => &1.preview_photo}))
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
            selected_preview: selected_preview,
            products: products
          }
        } = socket
      ) do
    product_id = String.to_integer(product_id)

    [preview | _] =
      Enum.filter(products, fn product ->
        product.id == product_id
      end)

    {selected, selected_preview} =
      if Enum.member?(selected, product_id) do
        selected_preview =
          Map.merge(selected_preview, %{
            product_id => Map.put(preview.preview_photo, :selected, false)
          })

        {List.delete(selected, product_id), selected_preview}
      else
        selected_preview =
          Map.merge(selected_preview, %{product_id => Map.put(photo, :selected, true)})

        {[product_id | selected], selected_preview}
      end

    updated_products =
      Enum.map(products, fn product ->
        Map.put(product, :preview_photo, Map.get(selected_preview, product.id))
      end)

    socket
    |> assign(:selected_preview, selected_preview)
    |> assign(:updated_products, updated_products)
    |> assign(preview: preview_url(photo, blank: true), category: preview.category)
    |> assign(:selected, selected)
    |> assign(:changeset, changeset(%{preview_photo_id: photo.id}, [:preview_photo_id]))
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
            updated_products: updated_products,
            gallery_id: gallery_id
          }
        } = socket
      ) do
    Enum.each(selected, fn product_id ->
      [preview | _] =
        Enum.filter(updated_products, fn product ->
          product.id == product_id
        end)

      result = GalleryProducts.get(id: to_integer(preview.id), gallery_id: to_integer(gallery_id))

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
    <div class="flex flex-col p-10 bg-white rounded-lg">
      <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="font-sans text-3xl font-bold">
            Set as preview for which products?
          </h1>
          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-2 h-2 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
      </div>
      <div class="relative flex py-10 font-sans bg-white">
          <div id="product-preview" class="items-center grid grid-cols-3 gap-4">
              <%= for product <- @updated_products do %>
              <div class="items-center">
                <div
                id={"product-#{product.id}"}
                class={"flex p-6 font-sans text-black bg-gray-100 h-52 w-52 cursor-pointer #{Map.get(product.preview_photo, :selected, false) && 'preview-border'}"}
                phx-click="click" phx-target={@myself}
                phx-value-product={product.id}
                >
                  <div class="flex justify-center row-span-2 previewImg">
                    <.framed_preview  item_id={product.category.id} category={product.category} photo={product.preview_photo} />
                  </div>
                </div>
                <div class="flex items-center pt-4 font-sans fomt-bold">
                  <%= product.category.name %>
                </div>
              </div>
              <% end %>
          </div>
      </div>
      <div class="flex flex-row items-center justify-end w-full lg:items-start">
          <button
          phx-click="modal"
          phx-value-action="close"
          title="close modal"
          class="float-right px-6 py-2 mr-3 bg-white border border-black rounded-lg"
          >
            Cancel
          </button>
          <button
          phx-click="save"
          phx-target={@myself}
          aria-label="save"
          class="float-right px-6 py-2 text-white bg-black rounded-lg"
          >
            Save changes
          </button>
      </div>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
