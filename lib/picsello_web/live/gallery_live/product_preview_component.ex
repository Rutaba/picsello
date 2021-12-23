defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries.Workers.PhotoStorage

  def update(%{product: %{category_template: template} = product} = assigns, socket) do
    socket
    |> assign(assigns)
    |> push_event("set_preview", %{
      preview: get_preview(product),
      frame: template.name,
      coords: template.corners,
      target: "canvas#{template.id}"
    })
    |> ok
  end

  def get_preview(%{preview_photo: %{preview_url: url}}), do: path(url)
  def get_preview(_), do: path(nil)

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
