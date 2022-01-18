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

  defp set_preview(%{assigns: %{category_template: template, photo: nil}} = socket) do
    socket
    |> push_event("set_preview", %{
      preview: path(nil),
      width: nil,
      height: nil,
      frame: template.name,
      coords: template.corners,
      target: "canvas#{template.id}"
    })
  end

  defp set_preview(%{assigns: %{category_template: template, photo: photo}} = socket) do
    socket
    |> push_event("set_preview", %{
      preview: path(photo.preview_url),
      ratio: photo.aspect_ratio,
      frame: template.name,
      coords: template.corners,
      target: "canvas#{template.id}"
    })
  end
end
