defmodule PicselloWeb.GalleryLive.ClientShow.Cart.Summary do
  @moduledoc """
    breaks down order price in a table
  """
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  import Money.Sigils

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(fn %{assigns: %{id: id, order: order}} = socket ->
      socket
      |> assign_new(:class, fn -> id end)
      |> assign_new(:inner_block, fn -> [] end)
      |> assign(details(order))
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

      <div class="px-5 grid grid-cols-[1fr,max-content] gap-3 mt-6 mb-5">
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

  def details(%{products: products, digitals: digitals} = order)
      when is_list(products) and is_list(digitals) do
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
    for {_label, %Money{} = price} <- charges, reduce: ~M[0]USD do
      acc -> Money.add(acc, price)
    end
  end

  defp sum_prices(items) do
    for %{price: price} <- items, reduce: ~M[0]USD do
      acc -> Money.add(acc, price)
    end
  end

  defp discounts(order),
    do:
      Enum.flat_map(
        [&product_discount_lines/1, &print_credit_lines/1, &digital_discount_lines/1],
        & &1.(order)
      )

  defp charges(order),
    do:
      Enum.flat_map(
        [&product_charge_lines/1, &digital_charge_lines/1, &bundle_charge_lines/1],
        & &1.(order)
      )

  defp product_charge_lines(%{products: []}), do: []

  defp product_charge_lines(%{products: products}),
    do: [
      {"Products (#{length(products)})", sum_prices(products)},
      {"Shipping & handling", "Included"}
    ]

  defp digital_charge_lines(%{digitals: []}), do: []

  defp digital_charge_lines(%{digitals: digitals}),
    do: [{"Digital downloads (#{length(digitals)})", sum_prices(digitals)}]

  defp bundle_charge_lines(%{bundle_price: nil}), do: []

  defp bundle_charge_lines(%{bundle_price: price}),
    do: [{"Bundle - all digital downloads", price}]

  defp product_discount_lines(%{products: products}) do
    for %{volume_discount: discount} <- products, reduce: ~M[0]USD do
      acc -> Money.subtract(acc, discount)
    end
    |> case do
      ~M[0]USD -> []
      discount -> [{"Volume discount", discount}]
    end
  end

  defp digital_discount_lines(order) do
    case Enum.filter(order.digitals, & &1.is_credit) do
      [] ->
        []

      credited ->
        [
          {"Digital download credit (#{length(credited)})",
           credited |> Enum.reduce(~M[0]USD, &Money.subtract(&2, &1.price))}
        ]
    end
  end

  defp print_credit_lines(%{products: products}) do
    products
    |> Enum.reduce(~M[0]USD, &Money.add(&2, &1.print_credit_discount))
    |> case do
      ~M[0]USD -> []
      credit -> [{"Print credits used", Money.neg(credit)}]
    end
  end
end
