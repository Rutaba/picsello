defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.{Orders, Cart}

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
      {:ok, _order} -> Orders.get!(gallery, order_number)
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
    order = Orders.get!(gallery, order_number)

    socket
    |> assign_details(order)
    |> noreply()
  end

  defp assign_details(socket, order) do
    gallery = order.gallery

    socket
    |> assign(
      gallery: gallery,
      order: order,
      organization_name: gallery.organization.name,
      shipping_address: order.delivery_info.address,
      shipping_name: order.delivery_info.name
    )
    |> assign_cart_count(gallery)
  end

  defp tracking_link(assigns) do
    ~H"""
    <%= for %{carrier: carrier, tracking_url: url, tracking_number: tracking_number} <- @info.shipping_info do %>
      <a href={url} target="_blank" class="underline cursor-pointer">
        <%= carrier %>
        <%= tracking_number %>
      </a>
    <% end %>
    """
  end

  defp tracking(%{whcc_order: %{orders: sub_orders}}, %{editor_id: editor_id}) do
    Enum.find_value(sub_orders, fn
      %{editor_id: ^editor_id, whcc_tracking: tracking} ->
        tracking

      _ ->
        nil
    end)
  end

  defdelegate has_download?(order), to: Picsello.Orders
  defdelegate product_name(order), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate item_image_url(item), to: Cart
  defdelegate summary(assigns), to: PicselloWeb.GalleryLive.ClientShow.Cart.Summary
end
