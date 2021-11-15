defmodule PicselloWeb.Live.Pricing.Category.Product do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div {testid("product")}>
      <h2 class="flex items-center justify-between py-6 text-2xl font-bold">
        <div class="flex items-center">
          <button class="flex items-center justify-center w-6 h-6 mr-5 rounded-lg bg-base-300" title="Expand" type="button" phx-click="toggle-expand" phx-value-product-id={@product.id}>
            <div class="stroke-current text-base-100">
              <%= if @expanded do %>
              <.icon name="up" class="w-2 h-1" />
              <% else %>
              <.icon name="down" class="w-2 h-1" />
              <% end %>
            </div>
          </button>

          <%= @product.whcc_name %>
        </div>

        <button title="Expand All" type="button" disabled={!@expanded} {if @expanded, do: %{phx_click: "toggle-expand-all"}, else: %{}} phx-value-product-id={@product.id} class={classes("text-sm border rounded-lg border-blue-planning-300 px-2 py-1 flex items-center", %{"opacity-50" => !@expanded})}>
          <%= if all_expanded?(@product, @expanded) do %>
            <div class="pr-2 stroke-current text-blue-planning-300"><.icon name="up" class="w-3 h-1.5"/></div>
            <span class="text-base-300">Collapse All</span>
          <% else %>
            <div class="pr-2 stroke-current text-blue-planning-300"><.icon name="down" class="w-3 h-1.5"/></div>
            <span class="text-base-300">Expand All</span>
          <% end %>
        </button>
      </h2>

      <%= if @expanded do %>
        <div class="grid grid-cols-5">
          <.th class="rounded-l-lg"><span class="pl-8">Variation</span></.th>
          <.th>Base Cost</.th>
          <.th>Final Price</.th>
          <.th>Your Profit</.th>
          <.th class="rounded-r-lg">Markup</.th>

        <%= for {variation_id, i} <- @product |> variation_ids() |> Enum.with_index() do %>
            <.variation product={@product} variation_id={variation_id} expanded={@expanded} index={i} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def all_expanded?(_, nil), do: false

  def all_expanded?(product, expanded) do
    product |> variation_ids() |> MapSet.new() |> MapSet.equal?(expanded)
  end

  def variation_ids(%{attribute_categories: attribute_categories}) do
    attribute_categories |> hd |> Map.get("attributes") |> Enum.map(& &1["id"])
  end

  defp variation(assigns) do
    ~H"""
      <%= live_component PicselloWeb.Live.Pricing.Category.Variation, id: {@product.id, @variation_id}, product: @product, variation_id: @variation_id, expanded: MapSet.member?(@expanded, @variation_id), index: @index %>
    """
  end

  defp th(assigns) do
    assigns = Enum.into(assigns, %{class: ""})

    ~H"""
    <h3 class={"bg-base-300 text-base-100 uppercase py-3 font-bold #{@class} px-4" }>
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end
end
