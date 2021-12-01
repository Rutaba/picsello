defmodule PicselloWeb.Live.Pricing.Category.Variation do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"contents #{if @expanded, do: "expanded", else: "collapsed"}"}>
      <%= if @expanded do %>
        <button type="button" title="Expand" class="flex items-center p-4 text-xl font-bold rounded-lg sm:text-base sm:col-span-5 col-span-2 pointer bg-blue-planning-300 text-base-100" phx-click="toggle-expand" phx-target={@myself}>
          <.icon name="up" class="w-4 h-2 mr-12 stroke-current sm:mr-4 stroke-3" />
          <%= @variation.name %>
        </button>

        <%= for attribute <- @variation.attributes do %>
          <.attribute attribute={attribute} variation_id={@variation.id} update={@update} />
        <% end %>

      <% else %>
        <button type="button" title="Expand" class="flex items-center p-4 text-xl font-bold col-start-1 sm:text-base" phx-click="toggle-expand" phx-target={@myself}>
          <.icon name="down" class="w-4 h-2 mr-12 stroke-current sm:mr-4 stroke-3 text-blue-planning-300" />
          <%= @variation.name %>
        </button>

        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= min_base_price(@variation) %></div>
        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= final_price(@variation) %></div>
        <div class="flex items-center text-lg col-start-2 sm:text-base sm:col-start-4 pl-14 sm:p-4 text-base-250">From <%= profit(@variation) %></div>
        <div class="items-center hidden p-4 sm:flex text-base-250">From <%= markup(@variation) %></div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "toggle-expand",
        %{},
        %{assigns: %{variation: %{id: variation_id}, update: {component, id}}} = socket
      ) do
    send_update(component, id: id, toggle_expand_variation: variation_id)
    socket |> noreply()
  end

  defp attribute(assigns) do
    ~H"""
    <%= live_component PicselloWeb.Live.Pricing.Category.Attribute, attribute: @attribute, variation_id: @variation_id, id: Enum.join([@variation_id, @attribute.category_id, @attribute.id], "-"), update: @update %>
    """
  end

  defp final_price(%{attributes: attributes}) do
    attributes |> Enum.map(&Money.add(profit(&1), &1.price)) |> min_money()
  end

  defp profit(%{attributes: attributes}), do: attributes |> Enum.map(&profit/1) |> min_money()

  defp profit(%{price: price} = attribute), do: Money.multiply(price, markup(attribute) / 100)

  defp markup(%{attributes: attributes}) do
    min =
      attributes
      |> Enum.map(&markup/1)
      |> Enum.min()

    "#{min}%"
  end

  defp markup(%{markup: markup}), do: markup

  defp min_base_price(%{attributes: attributes}) do
    attributes |> Enum.map(& &1.price) |> min_money()
  end

  defp min_money(prices) do
    prices |> Enum.min(fn -> Money.new(0) end)
  end
end
