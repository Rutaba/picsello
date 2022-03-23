defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.Cart
  alias Picsello.Cart.Order
  alias Picsello.Cart.OrderNumber
  alias Picsello.GalleryProducts
  alias Picsello.Galleries
  import Cart, only: [preview_url: 1]

  def mount(_, _, conn) do
    conn
    |> assign(:from_checkout, false)
    |> ok()
  end

  def handle_params(
        %{"order_number" => order_number},
        _,
        %{assigns: %{gallery: gallery, live_action: :paid}} = socket
      ) do
    order_id = order_number |> OrderNumber.from_number()

    case Cart.get_unconfirmed_order(gallery.id) do
      {:ok, %{id: ^order_id} = order} ->
        order =
          if socket |> connected?() do
            Cart.confirm_order(order, Galleries.account_id(gallery))
          else
            order
          end

        gallery = Galleries.populate_organization_user(gallery)

        socket
        |> assign(:gallery, gallery)
        |> assign(:from_checkout, true)
        |> assign_details(gallery, order)
        |> assign_cart_count(gallery)
        |> noreply()

      _ ->
        socket
        |> push_patch(
          to:
            Routes.gallery_client_order_path(
              socket,
              :show,
              gallery.client_link_hash,
              order_number
            )
        )
        |> noreply()
    end
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
      order: order,
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
      <a href={@url} class="cursor-pointer underline"><%= @text %></a>
    """
  end

  defdelegate summary_counts(order), to: Cart
end
