defmodule PicselloWeb.Live.Pricing.Category.Variation do
  @moduledoc false
  use PicselloWeb, :live_component
  require Integer

  @default_markup 1.0

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(fn %{assigns: assigns} = socket ->
      socket
      |> assign(min_base_price: min_base_price(assigns), name: name(assigns))
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"contents #{if @expanded, do: "expanded", else: "collapsed"}"}> <%#<-- frickin' sweet! %>
      <%= if @expanded do %>
        <button type="button" title="Expand" class="flex items-center p-4 text-xl font-bold rounded-lg sm:text-base sm:col-span-5 col-span-2 pointer bg-blue-planning-300 text-base-100" phx-click="toggle-expand" phx-value-product-id={@product.id} phx-value-variation-id={@variation_id}>
          <.icon name="up" class="w-4 h-2 mr-12 stroke-current sm:mr-4 stroke-3" />
          <%= @name %>
        </button>

        <%= for %{name: name, price: price}  <- sub_variations(@product, @variation_id) do %>
          <div class="contents">
            <div class="items-center hidden py-8 pl-12 pr-4 font-bold sm:flex"><%= name %></div>
            <div class="items-center hidden px-4 py-8 sm:flex"><%= price %></div>
            <div class="items-center hidden px-4 py-8 sm:flex"><%= final_price(price) %></div>
            <div class="items-center hidden px-4 py-8 sm:flex"><%= profit(price) %></div>

            <div class="items-center hidden px-4 py-8 sm:flex">
            <input class="w-20 text-right text-input" type="text" value="100%" />
            </div>

            <div class="px-5 py-4 mt-4 text-lg font-bold capitalize border-t border-l rounded-tl-lg ml-14 sm:hidden"><%= name %></div>
            <div class="py-4 mt-4 border-t border-r rounded-tr-lg pl-14 sm:hidden"><%= profit(price) %></div>
            <hr class="block ml-20 mr-6 sm:hidden col-span-2" />
            <dl class="block py-2 pl-5 border-l ml-14 sm:hidden">
              <dt class="font-bold">Base Cost</dt>
              <dd><%= price %></dd>
            </dl>
            <dl class="py-2 border-b border-r rounded-br-lg pl-14 row-span-2 sm:hidden">
              <dt class="mb-4 font-bold">Markup</dt>
              <dd><input class="w-20 p-4 text-right text-input" type="text" value="100%" /></dd>
            </dl>
            <dl class="block pt-2 pb-3 pl-5 border-b border-l rounded-bl-lg ml-14 sm:hidden">
              <dt class="font-bold">Final price</dt>
              <dd><%= final_price(price) %></dd>
            </dl>
          </div>
        <% end %>

      <% else %>
        <button type="button" title="Expand" class="flex items-center p-4 text-xl font-bold col-start-1 sm:text-base" phx-click="toggle-expand" phx-value-product-id={@product.id} phx-value-variation-id={@variation_id}>
          <.icon name="down" class="w-4 h-2 mr-12 stroke-current sm:mr-4 stroke-3 text-blue-planning-300" />
          <%= @name %>
        </button>

        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= @min_base_price %></div>
        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= final_price(@min_base_price) %></div>
        <div class="flex items-center text-lg col-start-2 sm:text-base sm:col-start-4 pl-14 sm:p-4 text-base-250">From <%= profit(@min_base_price) %></div>
        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= markup(@min_base_price) %></div>
      <% end %>
    </div>
    """
  end

  defp final_price(min_base) do
    Money.add(min_base, profit(min_base))
  end

  defp profit(min_base), do: Money.multiply(min_base, @default_markup)

  defp markup(_), do: "#{trunc(@default_markup * 100)}%"

  defp sub_variations(%{attribute_categories: attribute_categories}, variation_id) do
    for(
      %{"attributes" => attributes, "name" => category_name} <- attribute_categories,
      %{
        "name" => name,
        "id" => id,
        "pricingRefs" => %{^variation_id => %{"base" => %{"value" => price}}}
      } <- attributes,
      do: %{name: "#{category_name} #{name}", id: id, price: Money.new(trunc(price * 100))}
    )
  end

  defp name(%{
         product: %{attribute_categories: [%{"attributes" => attributes} | _]},
         variation_id: id
       }) do
    for(%{"name" => name, "id" => ^id} <- attributes, do: name) |> hd
  end

  defp min_base_price(%{product: product, variation_id: id}) do
    product |> sub_variations(id) |> Enum.map(& &1.price) |> Enum.min(fn -> Money.new(0) end)
  end
end