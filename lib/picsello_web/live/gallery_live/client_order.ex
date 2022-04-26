defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Cart, GalleryProducts, Galleries}
  import Cart, only: [item_image_url: 1]

  def mount(_, _, socket) do
    socket
    |> assign(from_checkout: false)
    |> ok()
  end

  def handle_params(
        %{"order_number" => order_number, "session_id" => session_id},
        _,
        %{assigns: %{gallery: gallery, live_action: :paid}} = socket
      ) do
    case Cart.confirm_order(
           order_number,
           session_id,
           PicselloWeb.Helpers
         ) do
      {:ok, order} -> order
    end
    |> then(fn order ->
      if connected?(socket) do
        socket
        |> assign(from_checkout: true)
        |> push_patch(
          to:
            Routes.gallery_client_order_path(
              socket,
              :show,
              gallery.client_link_hash,
              order_number
            ),
          replace: true
        )
      else
        socket
      end
      |> assign_details(order)
      |> noreply()
    end)
  end

  def handle_params(
        %{"order_number" => order_number},
        _,
        %{assigns: %{gallery: gallery}} = socket
      ) do
    order = Cart.get_placed_gallery_order!(gallery, order_number)

    socket
    |> assign_details(order)
    |> noreply()
  end

  defp assign_details(%{assigns: %{gallery: gallery}} = socket, order) do
    gallery =
      gallery
      |> Galleries.populate_organization_user()

    socket
    |> assign(
      gallery: gallery,
      order: Cart.preload_products(order),
      organization_name: gallery.job.client.organization.name,
      shipping_address: order.delivery_info.address,
      shipping_name: order.delivery_info.name
    )
    |> assign_cart_count(gallery)
  end

  defp product_description(%{id: id}) do
    assigns = %{
      product: GalleryProducts.get_whcc_product(id)
    }

    ~H"""
    <%= @product.whcc_name %>
    """
  end

  defp tracking_link(%{info: info}) do
    data = info["ShippingInfo"] |> Enum.at(0)

    assigns = %{
      url: data["TrackingUrl"],
      text: [data["Carrier"], data["TrackingNumber"]] |> Enum.join(" ")
    }

    ~H"""
      <a href={@url} class="underline cursor-pointer"><%= @text %></a>
    """
  end

  defdelegate quantity(item), to: Cart.CartProduct
  defdelegate total_cost(order), to: Cart
  defdelegate has_download?(order), to: Cart
end
