defmodule PicselloWeb.GalleryLive.ClientShow.Cart do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Cart
  alias Picsello.WHCC.Shipping
  alias Picsello.Galleries

  @impl true
  def mount(_params, _session, %{assigns: %{gallery: gallery}} = socket) do
    case Cart.get_unconfirmed_order(gallery.id) do
      {:ok, order} ->
        socket
        |> assign(:order, order)
        |> assign(:step, :product_list)
        |> ok()

      _ ->
        socket
        |> push_redirect(
          to: Routes.gallery_client_show_path(socket, :show, gallery.client_link_hash)
        )
        |> ok()
    end
  end

  @impl true
  def handle_event("continue", _, %{assigns: %{step: :product_list, order: order}} = socket) do
    socket
    |> assign(:step, :delivery_info)
    |> assign(:delivery_info_changeset, Cart.order_delivery_info_change(order))
    |> noreply()
  end

  @impl true
  def handle_event("continue", _, %{assigns: %{step: :delivery_info}} = socket) do
    socket
    |> assign(:step, :shipping_opts)
    |> assign_shipping_opts()
    |> assign_shipping_cost()
    |> noreply()
  end

  @impl true
  def handle_event(
        "checkout",
        _,
        %{
          assigns: %{
            step: :shipping_opts,
            shipping_opts: shipping_opts,
            order: %{products: products},
            gallery: gallery
          }
        } = socket
      ) do
    account_id = Galleries.get_gallery!(gallery.id) |> Galleries.account_id()

    order =
      Enum.map(products, fn product ->
        shipping_option =
          Enum.find(shipping_opts, fn opt ->
            opt[:editor_id] == product.editor_details.editor_id
          end)
          |> then(& &1.current)

        Cart.order_product(product, account_id,
          ship_to: ship_address(),
          return_to: ship_address(),
          attributes: Shipping.to_attributes(shipping_option)
        )
      end)
      |> Cart.store_cart_products_checkout()

    {:ok, %{link: checkout_link}} =
      payments().checkout_link(order,
        success_url:
          Routes.gallery_client_order_url(socket, :paid, gallery.client_link_hash, order.id),
        cancel_url: Routes.gallery_client_show_cart_url(socket, :cart, gallery.client_link_hash)
      )

    socket
    |> redirect(external: checkout_link)
    |> noreply()
  end

  def handle_event(
        "click",
        %{"option-uid" => option_uid, "product-editor-id" => editor_id},
        %{assigns: %{step: :shipping_opts}} = socket
      ) do
    socket
    |> update_shipping_opts(String.to_integer(option_uid), editor_id)
    |> assign_shipping_cost()
    |> noreply()
  end

  defp update_shipping_opts(%{assigns: %{shipping_opts: opts}} = socket, option_uid, editor_id) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(opts, fn
        %{editor_id: id, current: {uid, _, _, _}} = opt
        when editor_id == id and option_uid == uid ->
          opt

        %{editor_id: id} = opt when editor_id == id ->
          Map.put(
            opt,
            :current,
            Enum.find(opt[:list], fn list_opt -> option_uid == elem(list_opt, 0) end)
          )

        opt ->
          opt
      end)
    )
  end

  defp assign_shipping_opts(
         %{assigns: %{step: :shipping_opts, order: %{products: products}}} = socket
       ) do
    socket
    |> assign(
      :shipping_opts,
      Enum.map(products, fn product -> shipping_opts_for_product(product) end)
    )
  end

  defp assign_shipping_cost(%{assigns: %{step: :shipping_opts, shipping_opts: opts}} = socket) do
    socket
    |> assign(
      :shipping_cost,
      Enum.reduce(opts, Money.new(0), fn %{current: {_, _, _, cost}}, sum ->
        cost |> Money.parse!() |> Money.add(sum)
      end)
    )
  end

  defp display_shipping_opts(assigns) do
    ~H"""
    <form>
      <%= for option <- @options do %>
        <%= render_slot(@inner_block, option) %>
      <% end %>
    </form>
    """
  end

  defp shipping_opts_for_product(%{
         editor_details: %{editor_id: editor_id, selections: %{"size" => size}}
       }) do
    %{editor_id: editor_id, list: Shipping.options(size)}
    |> then(&Map.put(&1, :current, List.first(&1.list)))
  end

  defp shipping_opts_for_product(opts, %{editor_details: %{editor_id: editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> then(& &1.list)
  end

  defp is_current_shipping_option?(opts, option, %{editor_details: %{editor_id: editor_id}}) do
    Enum.find(opts, fn %{editor_id: id} -> id == editor_id end)
    |> then(&(&1.current == option))
  end

  defp shipping_option_uid({uid, _, _, _}), do: uid
  defp shipping_option_cost({_, _, _, cost}), do: Money.parse!(cost)
  defp shipping_option_label({_, label, _, _}), do: label

  defp ship_address() do
    %{
      "Name" => "Returns Department",
      "Addr1" => "3432 Denmark Ave",
      "Addr2" => "Suite 390",
      "City" => "Eagan",
      "State" => "MN",
      "Zip" => "55123",
      "Country" => "US",
      "Phone" => "8002525234"
    }
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
