defmodule PicselloWeb.GalleryLive.Photos.PreviewComponent do
  @moduledoc "no doc"

  use PicselloWeb, :live_component

  @default_assigns %{
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

  defdelegate min_price(category), to: Picsello.WHCC

  defp to_event_args(category),
    do: %{
      frame: Picsello.Category.frame_image(category),
      coords: Picsello.Category.coords(category),
      target: category.id
    }
end
