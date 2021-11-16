defmodule PicselloWeb.Live.Pricing.Category.Product do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div {testid("product")}>
      <h2 class="flex items-center justify-between py-6 text-2xl" title="Expand" type="button" phx-click="toggle-expand" phx-value-product-id={@product.id} >
        <button class="flex items-center font-bold">
          <div class="w-8 h-8 mr-6 rounded-lg stroke-current sm:w-6 sm:h-6 bg-base-300 text-base-100">
            <.icon name="up" class={"w-full h-full p-2.5 sm:p-2 stroke-4 #{if(@expanded, do: "rotate-180")}"} />
          </div>

          <%= @product.whcc_name %>
        </button>

        <button title="Expand All" type="button" disabled={!@expanded} {if @expanded, do: %{phx_click: "toggle-expand-all"}, else: %{}} phx-value-product-id={@product.id} class={classes("text-sm border rounded-lg border-blue-planning-300 px-2 py-1 items-center hidden sm:flex", %{"opacity-50" => !@expanded})}>
          <%= if all_expanded?(@product, @expanded) do %>
            <div class="pr-2 stroke-current text-blue-planning-300"><.icon name="up" class="stroke-3 w-3 h-1.5"/></div>
            Collapse All
          <% else %>
            <div class="pr-2 stroke-current text-blue-planning-300"><.icon name="down" class="stroke-3 w-3 h-1.5"/></div>
            Expand All
          <% end %>
        </button>
      </h2>

      <div class="grid grid-cols-2 sm:grid-cols-5">
        <.th expanded={@expanded} class="flex pl-3 rounded-l-lg col-start-1 sm:pl-12">
          <%= if @expanded do %>
            <button title="Expand All" type="button" phx-click="toggle-expand-all" phx-value-product-id={@product.id} class="flex flex-col items-center justify-between block py-1.5 border rounded stroke-current sm:hidden w-7 h-7 border-base-100 stroke-3">
              <.icon name="up" class="w-3 h-1.5" />
              <.icon name="down" class="w-3 h-1.5" />
            </button>
          <% else %>
            <div class="block sm:hidden w-7"></div>
          <% end %>
          <div class="ml-10 sm:ml-0">Variation</div>
        </.th>
        <.th expanded={@expanded} class="hidden px-4 sm:block">Base Cost</.th>
        <.th expanded={@expanded} class="hidden px-4 sm:block">Final Price</.th>
        <.th expanded={@expanded} class="rounded-r-lg sm:rounded-none col-start-2 sm:col-start-4 pl-14 sm:pl-4">Your Profit</.th>
        <.th expanded={@expanded} class="hidden px-4 rounded-r-lg sm:block">Markup</.th>

        <%= if @expanded do %>
          <%= for {variation_id, i} <- @product |> variation_ids() |> Enum.with_index() do %>
            <.variation product={@product} variation_id={variation_id} expanded={@expanded} index={i} />
          <% end %>
        <% end %>
      </div>
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
    build_class = &"#{&1} #{if &2,
      do: "bg-base-300 text-base-100",
      else: "bg-base-200 text-base-250"}"

    ~H"""
    <h3 class={"uppercase py-3 font-bold #{build_class.(@class, @expanded)}" }>
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end
end
