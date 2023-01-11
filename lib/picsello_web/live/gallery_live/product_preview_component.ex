defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Shared, only: [min_price: 3]

  @default_assigns %{
    click_params: nil
  }

  def update(assigns, socket) do
    socket |> assign(@default_assigns) |> assign(assigns) |> ok()
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
