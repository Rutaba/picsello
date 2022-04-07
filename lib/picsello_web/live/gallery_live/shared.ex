defmodule PicselloWeb.GalleryLive.Shared do
  @moduledoc "Shared function among gallery liveViews"

  use Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [icon: 1]
  import PicselloWeb.Gettext, only: [ngettext: 3]
  alias Picsello.{Cart.Digital}

  def assign_cart_count(
        %{assigns: %{order: %Picsello.Cart.Order{placed_at: %DateTime{}}}} = socket,
        _
      ),
      do: assign(socket, cart_count: 0)

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

  def button(assigns) do
    assigns = Map.put_new(assigns, :class, "")
    button_attrs = Map.drop(assigns, [:inner_block, :__changed__, :class])

    ~H"""
    <button {button_attrs} class={"#{@class}
        flex items-center justify-center p-2 font-medium text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
        hover:text-base-100 hover:bg-base-300
        disabled:border-base-250 disabled:text-base-250 disabled:cursor-not-allowed disabled:opacity-60
    "}>
      <%= render_slot(@inner_block) %>

      <.icon name="forth" class="ml-2 h-3 w-2 stroke-current stroke-[3px]" />
    </button>
    """
  end

  def summary_counts(order) do
    for {label, collection, format_fn} <- [
          {"Products", order.products, &sum_prices/1},
          {"Digitals", Enum.filter(order.digitals, &Money.positive?(&1.price)), &sum_prices/1},
          {"Digital credits used", Enum.filter(order.digitals, &Money.zero?(&1.price)),
           &credits_display/1}
        ] do
      {label, Enum.count(collection), format_fn.(collection)}
    end
  end

  defp credits_display(collection) do
    "#{ngettext("%{count} credit", "%{count} credits", Enum.count(collection))} - #{sum_prices(collection)}"
  end

  defp sum_prices(collection) do
    Enum.reduce(collection, Money.new(0), &Money.add(&2, &1.price))
  end

  def price_display(%Digital{} = digital) do
    "#{if Money.zero?(digital.price), do: "1 credit - "}#{digital.price}"
  end

  def price_display(product), do: product.price
end
