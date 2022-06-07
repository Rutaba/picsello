defmodule PicselloWeb.GalleryLive.PhotographerOrders do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live"]
  alias Picsello.{Orders, Cart, Galleries}

  def mount(%{"id" => id}, _, socket) do
    socket |> assign(gallery: Galleries.get_gallery!(id), orders: Orders.all(id)) |> ok
  end

  defdelegate total_cost(order), to: Cart
end
