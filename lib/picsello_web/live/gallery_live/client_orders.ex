defmodule PicselloWeb.GalleryLive.ClientOrders do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Galleries}

  def handle_params(_, _, %{assigns: %{gallery: gallery}} = socket) do
    orders = Cart.get_orders(gallery.id)
    gallery = Galleries.populate_organization_user(gallery)

    socket
    |> assign(:gallery, gallery)
    |> assign(:orders, orders)
    |> noreply
  end

  defdelegate total_cost(order), to: Cart
end
