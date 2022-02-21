defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers

  @default_assigns %{
    edit_product_link: nil,
    click_params: nil,
    has_product_info: true
  }

  def update(assigns, socket) do
    socket
    |> assign(@default_assigns)
    |> assign(assigns)
    |> set_preview()
    |> ok
  end

  defp set_preview(%{assigns: %{category: category, photo: nil}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args()
      |> Map.merge(%{
        preview: path(nil),
        width: nil,
        height: nil
      })
    )
  end

  defp set_preview(%{assigns: %{category: category, photo: photo}} = socket) do
    socket
    |> push_event(
      "set_preview",
      category
      |> to_event_args()
      |> Map.merge(%{
        preview: path(photo.preview_url),
        ratio: photo.aspect_ratio
      })
    )
  end

  defp min_price(_category), do: Money.new(0)

  defp to_event_args(category),
    do: %{
      frame: Picsello.Category.frame_image(category),
      coords: Picsello.Category.coords(category),
      target: "canvas#{category.id}"
    }
end
