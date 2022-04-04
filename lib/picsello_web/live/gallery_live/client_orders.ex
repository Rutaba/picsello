defmodule PicselloWeb.GalleryLive.ClientOrders do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Galleries}
  import PicselloWeb.GalleryLive.Shared, only: [assign_cart_count: 2]

  def handle_params(_, _, %{assigns: %{gallery: gallery}} = socket) do
    orders = Cart.get_orders(gallery.id)

    %{job: %{client: %{organization: %{user: %{time_zone: time_zone}}}}} =
      gallery = Galleries.populate_organization_user(gallery)

    socket
    |> assign(gallery: gallery, orders: orders)
    |> assign_cart_count(gallery)
    |> noreply()
  end

  defp time_zone(%{job: %{client: %{organization: %{user: %{time_zone: time_zone}}}}}),
    do: time_zone

  defp quantity(%{editor_details: %{selections: %{"quantity" => quantity}}}), do: quantity

  defdelegate total_cost(order), to: Cart
  defdelegate preview_url(item), to: Cart
  defdelegate product_name(item), to: Cart
end
