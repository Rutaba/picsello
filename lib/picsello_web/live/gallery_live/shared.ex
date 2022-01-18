defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  def assign_cart_count(socket, gallery) do
    count =
      case Picsello.Cart.get_unconfirmed_order(gallery.id) do
        {:ok, order} -> Enum.count(order.products) + Enum.count(order.digitals)
        _ -> 0
      end

    socket
    |> Phoenix.LiveView.assign(:cart_count, count)
  end
end
