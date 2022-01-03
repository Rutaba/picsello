defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Product do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.GalleryProducts

  def update(%{product: %{editor_details: %{"product_id" => id}}} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:whcc_product, GalleryProducts.get_whcc_product(id))
    |> ok()
  end

  defp product_size(%{editor_details: %{"selections" => %{"size" => size}}}), do: size
  defp product_preview_url(%{editor_details: %{"preview_url" => url}}), do: url
end
