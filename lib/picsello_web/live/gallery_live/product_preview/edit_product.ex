defmodule PicselloWeb.GalleryLive.ProductPreview.EditProduct do
  @moduledoc "no doc"
  use PicselloWeb, :live_component

  require Logger
  import PicselloWeb.LiveHelpers
  import PicselloWeb.GalleryLive.Shared
  import Ecto.Changeset

  alias Picsello.Repo
  alias Picsello.Galleries
  alias Picsello.GalleryProducts

  @per_page 999_999

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
    socket
    |> assign(assigns)
    |> then(fn socket ->
      push_event(socket, "set_preview", %{
        preview: preview_url(preview.preview_photo, blank: true),
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
    |> assign_photos(@per_page, "all_photos")
    |> ok()
  end

  @impl true
  def handle_event(
        "click",
        %{"preview" => preview, "preview_photo_id" => preview_photo_id},
        %{assigns: %{category_id: category_id, frame: frame, coords: coords}} = socket
      ) do
    socket
    |> assign(:preview_photo_id, to_integer(preview_photo_id))
    |> assign(:selected, true)
    |> assign(:preview, preview_url(preview, blank: true))
    |> push_event("set_preview", %{
      preview: preview_url(preview, blank: true),
      frame: frame,
      coords: coords,
      target: "#{category_id}-edit"
    })
    |> noreply
  end

  @impl true
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white h-screen w-screen overflow-auto">
      <.preview assigns={assigns}>
        <div id={"preview-#{@category_id}"} class="flex justify-center items-start row-span-2 previewImg" phx-hook="Preview">
          <canvas id={"canvas-#{@category_id}-edit"} width="300" height="255" class="edit bg-gray-300"></canvas>
        </div>
      </.preview>
    </div>
    """
  end
end
