defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Summary do
  @moduledoc """
    breaks down order price in a table
  """
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Cart

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(fn %{assigns: %{id: id, order: order}} = socket ->
      socket |> assign_new(:class, fn -> id end) |> assign(details(order))
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"flex flex-col border border-base-200 #{@class}"}>
      <button type="button" phx-click={toggle(@class)} class="block px-5 pt-4 text-base-250 lg:hidden">
        <div class="flex items-center pb-2">
          <.icon name="up" class="toggle w-5 h-2.5 stroke-2 stroke-current mr-2.5" />
          <.icon name="down" class="hidden toggle w-5 h-2.5 stroke-2 stroke-current mr-2.5" />
          See&nbsp;
          <span class="toggle">more</span>
          <span class="hidden toggle">less</span>
        </div>
        <hr class="mb-1 border-base-200">
      </button>

      <div class="px-5 grid grid-cols-[1fr,max-content] gap-3 mt-6">
        <dl class="text-lg contents">
          <%= for {label, value} <- @charges do %>
            <dt class="hidden toggle lg:block"><%= label %></dt>

            <dd class="self-center hidden toggle lg:block justify-self-end"><%= value %></dd>
          <% end %>

          <dt class="hidden text-2xl toggle lg:block">Subtotal</dt>
          <dd class="self-center hidden text-2xl toggle lg:block justify-self-end"><%= @subtotal %></dd>
        </dl>

        <%= unless @discounts == [] do %>
          <hr class="hidden mt-2 mb-3 toggle lg:block col-span-2 border-base-200">

          <dl class="text-lg contents text-green-finances-300">
            <%= for {label, value} <- @discounts do %>
              <dt class="hidden toggle lg:block"><%= label %></dt>

              <dd class="self-center hidden toggle lg:block justify-self-end">-<%= Money.neg(value) %></dd>
            <% end %>
          </dl>
        <% end %>

        <hr class="hidden mt-2 mb-3 col-span-2 border-base-200 toggle lg:block">

        <dl class="contents">
          <dt class="text-2xl font-extrabold">Total</dt>

          <dd class="self-center text-2xl font-extrabold justify-self-end"><%= @total %></dd>
        </dl>
      </div>

      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def details(order) do
    charges = charges(order)
    discounts = discounts(order)

    %{
      charges: charges,
      subtotal: sum_lines(charges),
      discounts: discounts,
      total: sum_lines(charges ++ discounts)
    }
  end

  def summary(assigns) do
    assigns =
      assign_new(assigns, :id, fn -> "summary-for-order-#{Map.get(assigns, :order).id}" end)

    ~H"""
    <.live_component module={__MODULE__} {assigns} />
    """
  end

  defp toggle(class),
    do: JS.toggle(to: ".#{class} > button .toggle") |> JS.toggle(to: ".#{class} .grid .toggle")

  defp sum_lines(charges) do
    for {_label, %Money{} = price} <- charges, reduce: Money.new(0) do
      acc -> Money.add(acc, price)
    end
  end

  defp discounts(order) do
    discount_sum =
      for %{price_without_discount: no_discount, price: price} <- priced_lines(order),
          reduce: Money.new(0) do
        acc -> Money.add(acc, Money.subtract(price, no_discount))
      end

    product_discount_lines =
      if Money.negative?(discount_sum) do
        [{"Volume discount", discount_sum}]
      else
        []
      end

    digital_discount_lines =
      case Enum.count(order.digitals, &Money.zero?(&1.price)) do
        0 ->
          []

        count ->
          [
            {"Digital download credit (#{count})",
             Money.multiply(order.package.download_each_price, -count)}
          ]
      end

    product_discount_lines ++ digital_discount_lines
  end

  defp charges(order) do
    lines = priced_lines(order)

    total_without_discount =
      for %{price_without_discount: price} <- lines, reduce: Money.new(0) do
        acc -> Money.add(acc, price)
      end

    product_lines =
      case lines do
        [] ->
          []

        _prices ->
          [
            {"Products (#{Enum.count(lines)})", total_without_discount},
            {"Shipping & handling", "Included"}
          ]
      end

    digital_lines =
      case Enum.count(order.digitals) do
        0 ->
          []

        count ->
          [
            {"Digital downloads (#{count})",
             Money.multiply(order.package.download_each_price, count)}
          ]
      end

    bundle_lines =
      case order.bundle_price do
        nil -> []
        price -> [{"Bundle - all digital downloads", price}]
      end

    product_lines ++ digital_lines ++ bundle_lines
  end

  defdelegate priced_lines(order), to: Cart
end
