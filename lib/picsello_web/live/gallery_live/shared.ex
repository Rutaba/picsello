defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  import Phoenix.LiveView, only: [assign: 2]

  def assign_cart_count(%{assigns: %{order: %Picsello.Cart.Order{} = order}} = socket, _) do
    socket
    |> assign(cart_count: Picsello.Cart.item_count(order))
  end

  def assign_cart_count(socket, gallery) do
    case Picsello.Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket |> assign(order: order) |> assign_cart_count(gallery)

      _ ->
        socket |> assign(cart_count: 0, order: nil)
    end
  end
end
