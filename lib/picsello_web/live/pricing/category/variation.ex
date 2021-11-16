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
      |> assign(
        border_class:
          if(Map.get(assigns, :index) == 0,
            do: "",
            else: "border-t"
          ),
        min_base_price: min_base_price(assigns),
        name: name(assigns)
      )
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="contents"> <%#<-- frickin' sweet! %>
      <%= if @expanded do %>
        <button type="button" title="Expand" class="flex items-center p-4 font-bold rounded-lg sm:col-span-5 col-span-2 pointer bg-blue-planning-300 text-base-100" phx-click="toggle-expand" phx-value-product-id={@product.id} phx-value-variation-id={@variation_id}>
          <.icon name="up" class="w-4 h-2 mr-4 stroke-current" />
          <%= @name %>
        </button>

        <%= for {%{name: name, price: price}, i} <- @product |> sub_variations(@variation_id) |> Enum.with_index(), bg = if(Integer.is_odd(i), do: "bg-blue-planning-100", else: "") do %>
          <div class={"hidden sm:flex pl-12 flex items-center font-bold py-8 pr-4 #{bg}"}><%= name %></div>
          <div class={"hidden sm:flex py-8 px-4 flex items-center #{bg}"}><%= price %></div>
          <div class={"hidden sm:flex py-8 px-4 flex items-center #{bg}"}><%= final_price(price) %></div>
          <div class={"hidden sm:flex py-8 px-4 flex items-center #{bg}"}><%= profit(price) %></div>

          <div class={"hidden sm:flex py-8 px-4 flex items-center #{bg}"}>
            <input class="w-20 text-right text-input" type="text" value="100%" />
          </div>

          <div class="px-5 py-4 mt-4 font-bold border-t border-l rounded-tl-lg ml-7 sm:hidden"><%= name %></div>
          <div class="p-4 mt-4 border-t border-r rounded-tr-lg sm:hidden"><%= profit(price) %></div>
          <hr class="block ml-12 mr-5 sm:hidden col-span-2" />
          <dl class="block py-2 pl-5 border-l ml-7 sm:hidden">
            <dt class="font-bold">Base cost</dt>
            <dd><%= price %></dd>
          </dl>
          <dl class="py-2 pl-4 border-b border-r rounded-br-lg row-span-2 sm:hidden">
            <dt class="mb-4 font-bold">Markup</dt>
            <dd><input class="w-20 p-4 text-right text-input" type="text" value="100%" /></dd>
          </dl>
          <dl class="block pt-2 pb-3 pl-5 border-b border-l rounded-bl-lg ml-7 sm:hidden">
            <dt class="font-bold">Final price</dt>
            <dd><%= final_price(price) %></dd>
          </dl>
        <% end %>

      <% else %>
        <button type="button" title="Expand" class={"col-start-1 flex items-center p-4 font-bold #{@border_class} pointer"} phx-click="toggle-expand" phx-value-product-id={@product.id} phx-value-variation-id={@variation_id}>
          <.icon name="down" class="w-4 h-2 mr-4 stroke-current text-blue-planning-300" />
          <%= @name %>
        </button>

        <div class={"hidden sm:flex items-center p-4 #{@border_class} text-base-250"}>From <%= @min_base_price %></div>
        <div class={"hidden sm:flex items-center p-4 #{@border_class} text-base-250"}>From <%= final_price(@min_base_price) %></div>
        <div class={"col-start-2 sm:col-start-4 flex items-center p-4 #{@border_class} text-base-250"}><%= profit(@min_base_price) %></div>
        <div class={"hidden sm:flex items-center p-4 #{@border_class} text-base-250"}>From <%= markup(@min_base_price) %></div>
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
