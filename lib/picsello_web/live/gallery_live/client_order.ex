defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Cart
  alias Picsello.Cart.Order
  alias Picsello.GalleryProducts
  alias Picsello.Galleries

  def mount(_, _, conn) do
    conn
    |> assign(:from_checkout, false)
    |> ok()
  end

  def handle_params(
        %{"order_id" => order_id},
        _,
        %{assigns: %{gallery: gallery, live_action: :paid}} = socket
      ) do
    order_id = to_integer(order_id)

    with {:ok, %{id: ^order_id} = order} <- Cart.get_unconfirmed_order(gallery.id) do
      order = Cart.confirm_order(order, Galleries.account_id(gallery))

      socket
      |> assign(:from_checkout, true)
      |> assign_details(gallery, order)
      |> noreply()
    else
      _ ->
        socket
        |> push_patch(
          to: Routes.gallery_client_order_path(socket, :show, gallery.client_link_hash, order_id)
        )
        |> noreply()
    end
  end

  def handle_params(%{"order_id" => order_id}, _, %{assigns: %{gallery: gallery}} = socket) do
    %Order{} = order = Cart.get_placed_gallery_order(order_id, gallery.id)

    socket
    |> assign(:from_checkout, false)
    |> assign_details(gallery, order)
    |> noreply()
  end

  defp assign_details(conn, gallery, order) do
    gallery =
      gallery
      |> Galleries.populate_organization()

    org_name = gallery.job.client.organization.name

    conn
    |> assign(:order, order)
    |> assign(:organization_name, org_name)
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
end
