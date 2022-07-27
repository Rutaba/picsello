defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.Orders

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
    case Orders.handle_session(
           order_number,
           session_id
         ) do
      {:ok, _order, :already_confirmed} ->
        Orders.get!(gallery, order_number)

      {:ok, _order, :confirmed} ->
        order = Orders.get!(gallery, order_number)
        Picsello.Notifiers.OrderNotifier.deliver_order_emails(order, PicselloWeb.Helpers)
        order
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

  defdelegate has_download?(order), to: Picsello.Orders
  defdelegate summary(assigns), to: PicselloWeb.GalleryLive.ClientShow.Cart.Summary
end
