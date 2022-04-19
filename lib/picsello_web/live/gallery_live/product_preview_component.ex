defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @default_assigns %{
    edit_product_link: nil,
    click_params: nil,
    has_product_info: true
  }

  def update(assigns, socket) do
    socket
    |> assign(:uniq, UUID.uuid4())
    |> assign(@default_assigns)
    |> assign(assigns)
    |> set_preview()
    |> ok
  end

  defp set_preview(%{assigns: %{category: category, photo: nil, uniq: uniq}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args(uniq)
      |> Map.merge(%{
        preview: preview_url(%{}),
        width: nil,
        height: nil
      })
    )
  end

  defp set_preview(%{assigns: %{category: category, photo: photo, uniq: uniq}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args(uniq)
      |> Map.merge(%{
        preview: preview_url(photo),
        ratio: photo.aspect_ratio
      })
    )
  end

  defdelegate min_price(category), to: Picsello.WHCC

  defp to_event_args(category, uniq),
    do: %{
      frame: Picsello.Category.frame_image(category),
      coords: Picsello.Category.coords(category),
      target: "canvas#{category.id}-#{uniq}"
    }
end
