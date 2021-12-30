defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries.Workers.PhotoStorage

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

  defp path(nil), do: "/images/card_blank.png"
  defp path(url), do: PhotoStorage.path_to_url(url)
end
