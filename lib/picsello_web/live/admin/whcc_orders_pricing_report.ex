defmodule PicselloWeb.Live.Admin.WHCCOrdersPricingReport do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Orders, Cart, WHCC}
  alias Picsello.WHCC.Order.Created, as: WHCCOrder

  def mount(%{"order_number" => order_number}, _, socket) do
    order =
      Orders.get_order_from_order_number(order_number)
      |> Picsello.Repo.preload([:intent, :digitals, products: :whcc_product])

    charges = Picsello.Notifiers.UserNotifier.photographer_payment(order)

    socket
    |> assign(order: order)
    |> assign(photographer_payment: Map.get(charges, :photographer_payment))
    |> assign(photographer_charge: Map.get(charges, :photographer_charge) |> Money.neg())
    |> assign(stripe_fee: Map.get(charges, :stripe_fee) |> Money.neg())
    |> ok()
  end

  def render(assigns) do
    ~H"""
      <div class="w-screen text-xs">
        <table class="w-full table-fixed">
          <tr class="border">
              <th> Client Paid </th>
              <th> Shipping </th>
              <th> Print Cost for Photog</th>
              <th> Stripe fee </th>
              <th> Photographer Paid </th>
              <th> Photographer Got </th>
              <th> Discounted WHCC cost </th>
          </tr>
            <tr class="text-center w-full">
              <td><%= Cart.Order.total_cost(@order) %></td>
              <td><%= Cart.total_shipping(@order) %></td>
              <td><%= print_cost(@order) %></td>
              <td><%= @stripe_fee %></td>
              <td><%= @photographer_charge %></td>
              <td><%= @photographer_payment %></td>
              <td><%= discounted_price(@order) %></td>
            </tr>
        </table>
      </div>
    """
  end

  defp print_cost(%{whcc_order: nil}), do: nil

  defp print_cost(%{whcc_order: whcc_order}) do
    whcc_order |> WHCCOrder.total()
  end

  defp discounted_price(order) do
    account_id = Picsello.Galleries.account_id(order.gallery_id)

    discounted_price =
      Enum.reduce(order.products, Money.new(0), fn %{editor_id: editor_id}, acc ->
        %{total_markuped_price: price} = WHCC.get_item_attrs(account_id, editor_id)
        if price do
          Money.add(price, acc)
        else
          Money.add(Money.new(0), acc)
        end
      end)

    discounted_price
  end
end
