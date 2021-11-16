defmodule PicselloWeb.Live.Pricing.Category do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Repo, Category}

  @impl true
  def mount(%{"category_id" => id}, _session, socket) do
    socket |> assign_category(id) |> assign(expanded: %{}) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-blue-planning-100">
      <div class="px-6 py-8 center-container">
        <div class="flex items-center">
          <.live_link to={Routes.pricing_path(@socket, :index)} class="flex items-center justify-center mr-4 rounded-full w-9 h-9 bg-blue-planning-300">
            <.icon name="back" class="w-2 h-4 stroke-current text-base-100" />
          </.live_link>

          <.crumbs class="text-blue-planning-200">
            <:crumb to={Routes.user_settings_path(@socket, :edit)}>Settings</:crumb>
            <:crumb to={Routes.pricing_path(@socket, :index)}>Gallery Store Pricing</:crumb>
            <:crumb><%= @category.name %></:crumb>
          </.crumbs>
        </div>

        <div class="flex items-end justify-between mt-4">
          <h1 class="text-3xl font-bold">Adjust Pricing: <span class="font-medium"><%= @category.name %></span></h1>
          <button title="Expand All" type="button" class="items-center hidden p-3 border rounded-lg sm:flex border-base-300" phx-click="toggle-expand-all">
            <%= if all_expanded?(@category.products, @expanded) do %>
              <.icon name="up" class="w-4 h-2 mr-2 stroke-current" /> Collapse All
            <% else %>
              <.icon name="down" class="w-4 h-2 mr-2 stroke-current" /> Expand All
            <% end %>
          </button>
        </div>
      </div>
    </div>

    <div class="px-6 pt-8 center-container">
      <%= for product <- @category.products do %>
        <.product product={product} expanded={Map.get(@expanded, product.id)} />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "toggle-expand-all",
        %{"product-id" => product_id},
        %{assigns: %{expanded: expanded, category: %{products: products}}} = socket
      ) do
    product_id = String.to_integer(product_id)
    product = Enum.find(products, &(&1.id == product_id))

    if all_variations_expanded?(product, Map.get(expanded, product_id)) do
      assign(socket, :expanded, Map.put(expanded, product_id, MapSet.new()))
    else
      assign(
        socket,
        :expanded,
        Enum.reduce(variation_ids(product), expanded, fn variation_id, expanded ->
          Map.update(expanded, product_id, MapSet.new(), &MapSet.put(&1, variation_id))
        end)
      )
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-expand-all",
        %{},
        %{assigns: %{expanded: expanded, category: %{products: products}}} = socket
      ) do
    if all_expanded?(products, expanded) do
      assign(socket, :expanded, %{})
    else
      assign(
        socket,
        :expanded,
        Enum.reduce(products, expanded, &Map.put_new(&2, &1.id, MapSet.new()))
      )
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-expand",
        %{"product-id" => product_id, "variation-id" => variation_id},
        %{assigns: %{expanded: expanded}} = socket
      ) do
    product_id = String.to_integer(product_id)

    expanded =
      Map.update(
        expanded,
        product_id,
        MapSet.new(),
        &if(MapSet.member?(&1, variation_id),
          do: MapSet.delete(&1, variation_id),
          else: MapSet.put(&1, variation_id)
        )
      )

    socket |> assign(:expanded, expanded) |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-expand",
        %{"product-id" => product_id},
        %{assigns: %{expanded: expanded}} = socket
      ) do
    product_id = String.to_integer(product_id)

    expanded =
      if Map.has_key?(expanded, product_id),
        do: Map.drop(expanded, [product_id]),
        else: Map.put(expanded, product_id, MapSet.new())

    socket |> assign(:expanded, expanded) |> noreply()
  end

  defp all_expanded?(products, expanded) do
    [all, expanded] =
      [Enum.map(products, & &1.id), Map.keys(expanded)]
      |> Enum.map(&MapSet.new/1)

    MapSet.equal?(all, expanded)
  end

  defdelegate all_variations_expanded?(product, expanded),
    to: __MODULE__.Product,
    as: :all_expanded?

  defdelegate variation_ids(product), to: __MODULE__.Product

  defp product(assigns) do
    ~H"""
    <%= live_component(__MODULE__.Product, product: @product, id: @product.id, expanded: @expanded) %>
    """
  end

  defp assign_category(socket, id) do
    socket |> assign(category: Category |> Repo.get!(id) |> Repo.preload(:products))
  end
end
