defmodule PicselloWeb.GalleryLive.ClientOrders do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{Cart, Galleries}

  import PicselloWeb.GalleryLive.Shared,
    only: [assign_cart_count: 2, price_display: 1, bundle_image: 1]

  def handle_params(_, _, %{assigns: %{gallery: gallery}} = socket) do
    orders = Cart.get_orders(gallery.id)

    gallery = Galleries.populate_organization_user(gallery)

    socket
    |> assign(gallery: gallery, orders: orders)
    |> assign_cart_count(gallery)
    |> noreply()
  end

  defp order_date(
         %{job: %{client: %{organization: %{user: %{time_zone: time_zone}}}}},
         %{placed_at: placed_at},
         format
       ),
       do: strftime(time_zone, placed_at, format)

  defp item_frame(assigns) do
    assigns = Enum.into(assigns, %{quantity: [], shipping: []})

    ~H"""
      <div class="block py-6 lg:justify-between lg:py-8 lg:flex">
        <div class="grid gap-4 grid-cols-[120px,1fr,min-content] lg:grid-cols-[147px,1fr]">
          <.item_image item={@item} />

          <div class="flex flex-col justify-center py-2 align-self-center">
            <div class="flex items-baseline lg:flex-col">
              <span class="mr-2 text-lg lg:text-base lg:font-medium"><%= product_name(@item) %></span>
              <span class="text-lg font-extrabold lg:mt-2"><%= @price %></span>
            </div>

            <%= render_slot(@quantity) %>
          </div>

        </div>

        <%= render_slot(@shipping) %>
      </div>
    """
  end

  defp item_image(%{item: {:bundle, _order}} = assigns) do
    ~H"""
      <div class="h-32 w-[120px] lg:h-[120px] place-self-center">
        <.bundle_image url={item_image_url(@item)} />
      </div>
    """
  end

  defp item_image(assigns) do
    ~H"""
      <img src={item_image_url(@item)} class="object-contain h-32 lg:h-[120px] place-self-center"/>
    """
  end

  defdelegate has_download?(order), to: Cart
  defdelegate item_image_url(item), to: Cart
  defdelegate quantity(item), to: Cart.CartProduct
  defdelegate total_cost(order), to: Cart
  defp product_name({:bundle, _}), do: "All digital downloads"
  defp product_name(%Picsello.Cart.Digital{}), do: "Digital download"
  defp product_name(item), do: Cart.product_name(item)
end
