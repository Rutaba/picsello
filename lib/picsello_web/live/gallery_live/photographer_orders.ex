defmodule PicselloWeb.GalleryLive.PhotographerOrders do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live"]
  alias Picsello.{Cart, Galleries}

  def mount(%{"id" => id}, _, socket) do
    orders = Cart.get_orders(id)
    gallery = Galleries.get_gallery!(id)

    socket
    |> assign(:gallery, gallery)
    |> assign(:orders, orders)
    |> ok
  end

  defdelegate total_cost(order), to: Cart
end
