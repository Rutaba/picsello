defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Product do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.GalleryProducts

  def update(%{product: cart_product} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(
      :whcc_product,
      GalleryProducts.get_whcc_product(cart_product.editor_details["product_id"])
    )
    |> ok()
  end

  defp product_size(%{editor_details: %{"selections" => %{"size" => size}}}), do: size
  defp product_preview_url(%{editor_details: %{"preview_url" => url}}), do: url
end
