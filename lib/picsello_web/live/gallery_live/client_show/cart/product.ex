defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Product do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.GalleryProducts

  @default_attrs %{has_border: true, has_buttons: true}

  def update(
        %{
          product: %{
            editor_details: %{
              "product_id" => id,
              "preview_url" => preview_url,
              "selections" => %{"size" => size}
            }
          }
        } = assigns,
        socket
      ) do
    socket
    |> assign(@default_attrs)
    |> assign(assigns)
    |> assign(:size, size)
    |> assign(:preview_url, preview_url)
    |> assign(:whcc_product, GalleryProducts.get_whcc_product(id))
    |> ok()
  end
end
