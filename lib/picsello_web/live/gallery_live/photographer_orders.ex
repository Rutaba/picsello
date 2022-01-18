defmodule PicselloWeb.GalleryLive.PhotographerOrders do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Galleries}
  alias Picsello.Repo

  def mount(%{"id" => id}, _, socket) do
    orders = Cart.get_orders(id)
    gallery = Galleries.get_gallery!(id)
    IO.inspect ["###", orders, Map.keys(socket.assigns)] #

    socket
    |> assign(:gallery, gallery)
    |> assign(:orders, orders)
    |> ok
  end

  def render(assigns) do
    ~H"""
    YO!
    <%= for order <- @orders do %>
    <div class="lg:flex items-center justify-between p-5 md:p-8 bg-base-200 border rounded-t-lg border-base-250 relative">
      <div class="lg:flex items-center justify-between">
          <p class="lg:mr-8">
              <span class="font-semibold">Order placed: </span>
              <%= DateTime.to_string(order.placed_at) %>
          </p>
          <!-- *** *** *** !!! for wide screens (lg = 1024px) date should be in 'December 8, 2021' format !!! *** *** *** -->
          <p>
              <span class="font-semibold">Order total: </span>
              <%= Money.add(order.subtotal_cost, order.shipping_cost) %>
          </p>
      </div>
      <div class="lg:flex items-center justify-between">
          <p class="lg:mr-8">
              <span class="lg:font-semibold">Order number:</span>
              <span class="font-semibold lg:font-normal"><%= order.number %></span>
          </p>
          <p class="absolute top-5 right-5 lg:static">
          <%= live_redirect to: Routes.gallery_client_order_path(@socket, :show, @gallery.client_link_hash, order.id) do %>
              <p class="text-blue-planning-300">View details</p>
          <% end %>
          </p>
      </div>
    </div>
    <% end %>
    """
  end
end
