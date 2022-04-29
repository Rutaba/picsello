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
    product = GalleryProducts.get(id: to_integer(product_id))
    preview = GalleryProducts.get(id: product_id, gallery_id: gallery_id)

    [
      Map.merge(assigns, %{
        gallery: gallery,
        product: product,
        preview: preview,
        photo: preview.preview_photo,
        favorites_count: Galleries.gallery_favorites_count(gallery),
        frame_id: preview.category_id,
        category: preview.category,
        title: "#{product.category.name} preview"
      })
    ]
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(
      description:
        "Select one of your gallery photos that best showcases this product - your client will use this as a starting point, and can customize their product further in the editor.",
      favorites_filter: false,
      page: 0,
      page_title: "Product Preview",
      preview_photo_id: nil,
      selected: false
    )
    |> assign_photos(@per_page, "all_photos")
    |> ok()
  end

  @impl true
  def handle_event(
        "click",
        %{"preview_photo_id" => preview_photo_id},
        socket
      ) do
    preview_photo_id = to_integer(preview_photo_id)

    socket
    |> assign(
      preview_photo_id: preview_photo_id,
      selected: true,
      photo: Galleries.get_photo(preview_photo_id)
    )
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

    result = GalleryProducts.get(id: to_integer(product_id), gallery_id: to_integer(gallery_id))

    if result != nil do
      result
      |> cast(%{preview_photo_id: preview_photo_id, category_id: frame_id}, [
        :preview_photo_id,
        :category_id
      ])
      |> Repo.insert_or_update()

      send(
        self(),
        {:save, %{title: title}}
      )
    end

    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-screen h-screen overflow-auto bg-white">
      <.preview
        description={@description}
        favorites_count={@favorites_count}
        favorites_filter={@favorites_filter}
        gallery={@gallery}
        has_more_photos={@has_more_photos}
        page={@page}
        page_title={@page_title}
        photos={@photos}
        selected={@selected}
        myself={@myself}
        title={@title}>
        <div class="flex items-start justify-center row-span-2 previewImg">
          <.framed_preview category={@category} photo={@photo} id="framed-edit-preview" />
        </div>
      </.preview>
    </div>
    """
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
