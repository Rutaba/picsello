defmodule PicselloWeb.GalleryLive.GlobalSettings.PrintProductComponent do
  use PicselloWeb, :live_component
  alias Picsello.Repo
  alias Picsello.GlobalSettings

  @impl true
  def update(%{product: %{category: %{products: products}}} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:products, Repo.preload(products, :category))
    |> assign(:selections, %{})
    |> assign_print_products()
    |> ok()
  end

  defp print_item(%{selections: selections, product: product} = assigns) do
    p_selections = Map.get(selections, product.id)

    ~H"""
      <div class="flex flex-col">
        <div class={"flex flex-col p-3 border-t border-r border-l border-b-8 rounded-lg #{if(p_selections && p_selections.open?, do: "border-blue-planning-300", else: "border-base-250")}"}>
          <div class="flex p-3">
            <div class="bg-black rounded-lg p-2 mr-4 text-white h-fit cursor-pointer" phx-click="expand_product" phx-value-product_id={@product.id} phx-target={@myself}>
              <%= if p_selections && p_selections.open? do %>
                <.icon name="up" class="text-white w-3 h-3 stroke-current stroke-2"/>
              <% else %>
                <.icon name="down" class="text-white w-3 h-3 stroke-current stroke-2"/>
              <% end %>
            </div>
            <b class="text-lg">
              <%="#{@title}s"%>
            </b>
            <div class="flex ml-auto border rounded-lg items-center border-blue-planning-300 px-2 disabled:opacity-75" disabled={p_selections && !p_selections.open?}>
              <.icon name="down" class="text-blue-planning-300 w-3 h-3 stroke-current stroke-2 mr-3"/>
              <span phx-click="expand_all_products" class="cursor-pointer">Expand All</span>
            </div>
          </div>
          <div class={classes("grid grid-cols-4 p-2 pl-14 text-base-250", %{"text-base-300" => p_selections && p_selections.open?})}>
            <%= for item <- ["Variation", "Your Profit", "Base Cost", "Final Price"] do %>
              <div class="font-bold"><%= item %></div>
            <% end %>
          </div>
        </div>

        <%= if p_selections && p_selections.open? do %>
          <div class="border-l border-r border-b rounded-b border-blue-planning-300">
            <%= for {size, %{values: values, open?: open?}} <- p_selections.selections, value = Enum.min_by(values, & &1.base_cost) do %>
              <.size_row size={size} value={value} values={values} open?={open?} myself={@myself} print_products_map={@print_products_map} product={product} />
              <%= for %{type: type, base_cost: base_cost} <- values, open? == true do %>
                <div class="grid grid-cols-4 pl-12 py-2 cursor-pointer items-center hover:bg-blue-planning-100">
                  <% final_cost = final_cost(@print_products_map, product.id, size, type) || to_decimal(base_cost) %>

                  <div class="font-bold pl-4"><%= type %> </div>
                  <div class="pl-4">$<%= sub(final_cost, base_cost) %></div>
                  <div class=""><%= base_cost %></div>

                  <.form let={f} for={:size} phx-target={@myself} phx-change="final_cost" id={size <> type}>
                    <%= hidden_input f, :product_id, value: product.id %>
                    <%= hidden_input f, :type, value: type %>
                    <%= hidden_input f, :size, value: size %>
                    <%= input f, :final_cost, type: :number_input, min: 0, value: final_cost, class: "w-24 mt-2 h-12 border rounded-md border-blue-planning-300 p-4 text-center" %>
                  </.form>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
    </div>
    """
  end

  defp size_row(
         %{
           print_products_map: print_products_map,
           size: size,
           product: product,
           values: values,
           value: %{base_cost: base_cost}
         } = assigns
       ) do
    final_cost =
      values
      |> Enum.map(&final_cost(print_products_map, product.id, size, &1.type))
      |> Enum.min() || to_decimal(base_cost)

    ~H"""
    <div class={"grid grid-cols-4 pl-6 py-3 border-b border-base-200 cursor-pointer #{if @open?, do: "bg-blue-planning-300 rounded-lg"}"} phx-target={@myself} phx-click="expand_product_size" phx-value-size={size} phx-value-product_id={product.id}>
      <div class={"flex items-center font-bold pl-4 #{if @open?, do: "text-white", else: "text-black"}"}>
        <%= if @open? do %>
          <.icon name="up" class="w-3 h-3 stroke-current stroke-2 mr-4" />
        <% else %>
          <.icon name="down" class="w-3 h-3 stroke-current stroke-2 mr-4" />
        <% end %>
        <%= size %>
      </div>
      <%= if !@open? do %>
        <div class="pl-6 text-base-250">$<%= sub(final_cost, base_cost) %></div>
        <div class="pl-4 text-base-250"><%= base_cost %></div>
        <div class="text-base-250"><%= final_cost %> </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "expand_product",
        %{"product_id" => product_id},
        %{assigns: %{products: products, selections: selections}} = socket
      ) do
    product = find(products, product_id)

    selections
    |> Map.get(product.id)
    |> process_product(selections, product)
    |> then(&(socket |> assign(:selections, &1) |> noreply()))
  end

  def handle_event(
        "expand_product_size",
        %{"size" => size, "product_id" => product_id},
        %{assigns: %{selections: selections}} = socket
      ) do
    selections
    |> update_in([String.to_integer(product_id), :selections, size], &%{&1 | open?: !&1.open?})
    |> then(&(socket |> assign(:selections, &1) |> noreply()))
  end

  def handle_event(
        "final_cost",
        %{
          "size" => %{
            "final_cost" => final_cost,
            "product_id" => product_id,
            "size" => size,
            "type" => type
          }
        },
        %{assigns: %{print_products: print_products}} = socket
      ) do
    print_product = find(print_products, product_id, :product_id)

    print_product
    |> Map.get(:sizes)
    |> Enum.map(&build_params(&1, size, type, final_cost))
    |> then(&GlobalSettings.update_print_product!(print_product, %{sizes: &1}))

    socket |> assign_print_products() |> noreply()
  end

  def assign_print_products(%{assigns: %{product: product}} = socket) do
    print_products = GlobalSettings.list_print_products(product.id)

    socket
    |> assign(
      :print_products_map,
      Map.new(
        GlobalSettings.list_print_products(product.id),
        fn x ->
          {
            x.product_id,
            Map.new(x.sizes, &{&1.size <> &1.type, &1})
          }
        end
      )
    )
    |> assign(:print_products, print_products)
  end

  defp build_params(%{size: size, id: id, type: type}, size, type, final_cost),
    do: %{id: id, final_cost: final_cost}

  defp build_params(%{id: id}, _size, _type, _), do: %{id: id}

  defp process_product(nil, selections, product) do
    {categories, new_selections} = Picsello.Product.selections_with_prices(product)

    new_selections
    |> Enum.map(&GlobalSettings.size(&1, categories))
    |> Enum.group_by(& &1.size)
    |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, %{open?: false, values: v}) end)
    |> then(&Map.put(selections, product.id, %{open?: true, selections: &1}))
  end

  defp process_product(%{open?: open?} = p_selections, selections, product) do
    Map.put(selections, product.id, %{p_selections | open?: !open?})
  end

  defp final_cost(print_products, product_id, size, type) do
    print_products
    |> Map.get(product_id)
    |> Map.get(size <> type)
    |> Map.get(:final_cost)
  end

  defp sub(decimal, non_decimal), do: Decimal.sub(decimal, to_decimal(non_decimal))

  defp to_decimal(%{amount: amount}), do: Decimal.new(to_string(amount / 100))

  defp find(list, str_id, key \\ :id),
    do: Enum.find(list, &(&1 |> Map.get(key) |> to_string() == str_id))
end
