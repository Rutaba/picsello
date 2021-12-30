defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveHelpers

  @default_assigns %{
    edit_product_link: nil,
    click_params: nil,
    has_product_info: true
  }

  def mount(socket) do
    socket
    |> assign(@default_assigns)
    |> ok
  end

  def update(%{category_template: template, preview_url: preview_url} = assigns, socket) do
    socket
    |> assign(assigns)
    |> push_event("set_preview", %{
      preview: path(preview_url),
      frame: template.name,
      coords: template.corners,
      target: "canvas#{template.id}"
    })
    |> ok
  end
end
