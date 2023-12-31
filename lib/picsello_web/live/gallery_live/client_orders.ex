defmodule PicselloWeb.GalleryLive.ClientOrders do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_gallery_client"]
  alias Picsello.{Cart, Orders, Galleries}
  alias Cart.Order
  alias PicselloWeb.GalleryLive.Shared.DownloadLinkComponent

  import PicselloWeb.GalleryLive.Shared,
    only: [
      assign_cart_count: 2,
      price_display: 1,
      bundle_image: 1,
      product_name: 2,
      tracking: 1,
      credits_footer: 1,
      assign_checkout_routes: 1,
      assign_is_proofing: 1,
      get_client_by_email: 1,
      is_photographer_view: 1
    ]

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.GalleryLive.Shared

  @impl true
  def handle_params(
        _,
        _,
        %{assigns: %{gallery: gallery, client_email: client_email} = assigns} = socket
      ) do
    gallery_client = get_client_by_email(assigns)

    orders = Orders.gallery_client_orders(gallery.id, gallery_client.id) |> maybe_filter(assigns)
    Enum.each(orders, &Orders.subscribe/1)

    gallery = Galleries.populate_organization_user(gallery)

    gallery =
      Map.put(
        gallery,
        :credits_available,
        (client_email && client_email in gallery.gallery_digital_pricing.email_list) ||
          is_photographer_view(assigns)
      )

    socket
    |> assign(gallery: gallery, orders: orders, gallery_client: gallery_client)
    |> assign_is_proofing()
    |> assign_cart_count(gallery)
    |> assign_checkout_routes()
    |> assign_new(:album, fn -> nil end)
    |> noreply()
  end

  @impl true
  def handle_info({:pack, :ok, %{packable: %{id: id}, status: status}}, socket) do
    DownloadLinkComponent.update_status(id, status)

    socket |> noreply()
  end

  def handle_info({:pack, _, _}, socket), do: noreply(socket)

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.GalleryLive.Shared

  def order_route(%{socket: socket, album: album}, order)
      when album.is_proofing or album.is_finals do
    Routes.gallery_client_order_path(
      socket,
      :proofing_album,
      album.client_link_hash,
      Order.number(order)
    )
  end

  def order_route(%{gallery: gallery, socket: socket, is_proofing: false}, order) do
    Routes.gallery_client_order_path(socket, :show, gallery.client_link_hash, Order.number(order))
  end

  defp order_date(
         %{job: %{client: %{organization: %{user: %{time_zone: time_zone}}}}},
         %{placed_at: placed_at},
         format
       ),
       do: strftime(time_zone, placed_at, format)

  defp item_frame(assigns) do
    assigns = Enum.into(assigns, %{quantity: [], shipping: [], is_proofing: false})

    ~H"""
      <div class="block py-6 lg:justify-between lg:py-8 lg:flex">
        <div class="grid gap-4 grid-cols-[120px,1fr,min-content] lg:grid-cols-[147px,1fr]">
          <.item_image item={@item} is_proofing={@is_proofing}/>

          <div class="flex flex-col justify-center py-2 align-self-center">
            <div class="flex items-baseline lg:flex-col">
            <span class="mr-2 text-lg lg:text-base lg:font-medium"><%= product_name(@item, @is_proofing) %></span>
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
    <img src={item_image_url(@item, proofing_client_view?: @is_proofing)} class="object-contain h-32 lg:h-[120px] place-self-center"/>
    """
  end

  defp maybe_filter(orders, %{album: album}) when album.is_proofing or album.is_finals do
    Enum.filter(orders, &(&1.album_id == album.id))
  end

  defp maybe_filter(orders, _assigns) do
    Enum.reject(orders, & &1.album_id)
  end

  defdelegate canceled?(order), to: Orders
  defdelegate has_download?(order), to: Orders
  defdelegate item_image_url(item), to: Cart
  defdelegate item_image_url(item, opts), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate total_cost(order), to: Cart
  defdelegate total_shipping(order), to: Cart
  defdelegate download_link(assigns), to: DownloadLinkComponent
end
