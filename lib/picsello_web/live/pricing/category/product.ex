defmodule PicselloWeb.Live.Pricing.Category.Product do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def preload(list_of_assigns) do
    with [%{user: user} | _] <- list_of_assigns,
         [_ | _] = expanded_product_ids <-
           for(
             %{expanded: true, product: %{id: product_id, variations: nil}} <- list_of_assigns,
             do: product_id
           ) do
      product_map = Picsello.WHCC.preload_products(expanded_product_ids, user)

      for(%{product: %{id: product_id}} = assigns <- list_of_assigns) do
        case Map.get(product_map, product_id) do
          nil -> assigns
          product -> Map.merge(assigns, %{product: product})
        end
      end
    else
      _ -> list_of_assigns
    end
  end

  @impl true
  def update(
        %{markup: markup} = assigns,
        %{assigns: %{user: user, product: product}} = socket
      ) do
    assigns =
      case Picsello.Repo.insert(
             %{
               markup
               | organization_id: user.organization_id,
                 product_id: product.id,
                 value: markup.value / 1
             },
             on_conflict: :replace_all,
             conflict_target:
               ~w[organization_id product_id whcc_attribute_id whcc_variation_id whcc_attribute_category_id]a,
             returning: true
           ) do
        {:ok, markup} ->
          Map.put(assigns, :product, update_markup(product, markup))

        _ ->
          assigns
      end

    assigns
    |> Map.drop([:markup])
    |> update(socket)
  end

  @impl true
  def update(
        %{toggle_expand_variation: id} = assigns,
        %{assigns: %{expanded_variations: expanded}} = socket
      ) do
    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    assigns
    |> Map.drop([:toggle_expand_variation])
    |> Map.put(:expanded_variations, expanded)
    |> update(socket)
  end

  @impl true
  def update(assigns, socket) do
    socket |> assign(assigns) |> assign_new(:expanded_variations, fn -> MapSet.new() end) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div {testid("product")}>
      <h2 class="flex items-center justify-between py-6 text-2xl" title="Expand" phx-click="toggle-expand" phx-value-product-id={@product.id} >
        <button class="flex items-center font-bold">
          <div class="w-8 h-8 mr-6 rounded-lg stroke-current sm:w-6 sm:h-6 bg-base-300 text-base-100">
            <.icon name="down" class={"w-full h-full p-2.5 sm:p-2 stroke-4 #{if(@expanded, do: "rotate-180")}"} />
          </div>

          <%= @product.whcc_name %>
        </button>

        <button title="Expand All" type="button" disabled={!@expanded} {if @expanded, do: %{phx_click: "toggle-expand-all"}, else: %{}} phx-target={@myself} class={classes("text-sm border rounded-lg border-blue-planning-300 px-2 py-1 items-center hidden sm:flex", %{"opacity-50" => !@expanded})}>
          <%= if all_expanded?(@product.variations, @expanded_variations) do %>
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
            <button title="Expand All" type="button" phx-click="toggle-expand-all" phx-target={@myself} class="flex flex-col items-center justify-between block py-1.5 border rounded stroke-current sm:hidden w-7 h-7 border-base-100 stroke-3">
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
          <%= for variation <- @product.variations do %>
            <.variation product_id={@product.id} variation={variation} expanded={@expanded_variations} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "toggle-expand-all",
        %{},
        %{assigns: %{expanded_variations: expanded, product: %{variations: variations}}} = socket
      ) do
    if all_expanded?(variations, expanded) do
      assign(socket, :expanded_variations, MapSet.new())
    else
      assign(socket, :expanded_variations, id_set(variations))
    end
    |> noreply()
  end

  defp all_expanded?(nil, _expanded), do: false

  defp all_expanded?(variations, expanded),
    do: variations |> id_set() |> MapSet.equal?(expanded)

  defp id_set(variations), do: variations |> Enum.map(& &1.id) |> MapSet.new()

  defp variation(assigns) do
    ~H"""
    <%= live_component PicselloWeb.Live.Pricing.Category.Variation,
      id: [@product_id, @variation.id] |> Enum.concat(Enum.map(@variation.attributes, & &1.id)) |> Enum.join("-"),
      update: {__MODULE__, @product_id},
      variation: @variation,
      expanded: MapSet.member?(@expanded, @variation.id) %>
    """
  end

  defp th(assigns) do
    build_class =
      &"#{&1} #{if &2,
        do: "bg-base-300 text-base-100",
        else: "bg-base-200 text-base-250"}"

    ~H"""
    <h3 class={"uppercase py-3 font-bold #{build_class.(@class, @expanded)}" }>
      <%= render_slot(@inner_block) %>
    </h3>
    """
  end

  defp update_markup(product, markup) do
    %{
      product
      | variations:
          update_enum(
            product.variations,
            &(&1.id == markup.whcc_variation_id),
            fn variation ->
              %{
                variation
                | attributes:
                    update_enum(
                      variation.attributes,
                      &(&1.id == markup.whcc_attribute_id &&
                          &1.category_id == markup.whcc_attribute_category_id),
                      &%{&1 | markup: markup.value}
                    )
              }
            end
          )
    }
  end

  defp update_enum(enum, predicate, update),
    do: Enum.map(enum, &if(predicate.(&1), do: update.(&1), else: &1))
end
