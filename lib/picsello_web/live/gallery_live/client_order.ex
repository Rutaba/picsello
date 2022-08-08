defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc "Order display to client"

  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  import PicselloWeb.GalleryLive.Shared

  alias Picsello.Orders
  alias PicselloWeb.GalleryLive.Shared.DownloadLinkComponent

  @impl true
  def mount(_, _, socket) do
    socket
    |> assign(from_checkout: false)
    |> ok()
  end

  @impl true
  def handle_params(
        %{"order_number" => order_number, "session_id" => session_id},
        _,
        %{assigns: %{gallery: gallery, live_action: :paid}} = socket
      ) do
    order_number
    |> Orders.handle_session(session_id)
    |> Picsello.Notifiers.OrderNotifier.deliver_order_confirmation_emails(PicselloWeb.Helpers)
    |> case do
      {:ok, _email} ->
        Orders.get!(gallery, order_number)
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
    Orders.subscribe(order)

    socket
    |> assign_details(order)
    |> noreply()
  end

  @impl true
  def handle_info({:pack, :ok, %{path: path}}, %{assigns: %{order: order}} = socket) do
    DownloadLinkComponent.update_path(order, path)

    socket |> noreply()
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

  defdelegate canceled?(order), to: Picsello.Orders
  defdelegate has_download?(order), to: Picsello.Orders
  defdelegate summary(assigns), to: PicselloWeb.GalleryLive.ClientShow.Cart.Summary
end
