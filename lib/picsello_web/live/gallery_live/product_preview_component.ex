defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @default_assigns %{
    edit_product_link: nil,
    click_params: nil,
    has_product_info: true
  }

  def update(assigns, socket) do
    socket |> assign(@default_assigns) |> assign(assigns) |> ok()
  end

  defdelegate min_price(category), to: Picsello.WHCC
  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
end
