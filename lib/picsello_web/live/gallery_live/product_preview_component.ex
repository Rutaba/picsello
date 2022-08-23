defmodule PicselloWeb.GalleryLive.ProductPreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @default_assigns %{
    click_params: nil
  }

  def update(assigns, socket) do
    socket |> assign(@default_assigns) |> assign(assigns) |> ok()
  end

  defdelegate framed_preview(assigns), to: PicselloWeb.GalleryLive.FramedPreviewComponent
  defdelegate min_price(category), to: Picsello.Galleries
end
