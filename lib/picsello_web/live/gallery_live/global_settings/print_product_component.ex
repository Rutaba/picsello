defmodule PicselloWeb.GalleryLive.GlobalSettings.PrintProductComponent do
  @moduledoc false
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
    open? = p_selections && p_selections.open?
    icon_class = "w-3 h-3 stroke-current stroke-2"

    ~H"""
      <div class="flex flex-col">
      <div class={"flex flex-col p-3 border-t border-r border-l border-b-8 rounded-t-lg #{if(open?, do: "border-blue-planning-300", else: "border-base-250 rounded-b-lg")}"}>
          <div class="flex p-3">
            <div class="bg-black rounded-lg p-2 mr-4 text-white h-fit cursor-pointer" phx-click="expand_product" phx-value-product_id={@product.id} phx-target={@myself}>
              <.icon name={if open?, do: "up", else: "down"} class={"#{icon_class} text-white"} />
            </div>
            <b class="text-lg">
              <%="#{@title}s"%>
            </b>
            <.icon_button color="blue-planning-300" icon="down" class="flex ml-auto px-2" disabled={!open?} phx-click="expand_product_all" phx-value-product-id={product.id} phx-target={@myself}>
              Expand All
            </.icon_button>
          </div>
          <div class={classes("grid md:grid-cols-4 grid-cols-2 p-2 pl-14 text-base-250", %{"text-base-300" => open?})}>
            <%= for item <- ["Variation", "Your Profit", "Base Cost", "Final Price"] do %>
              <div class="font-bold hidden md:block"><%= item %></div>
            <% end %>
            <%= for item <- ["Variation", "Final Price"] do %>
              <div class="font-bold md:hidden"><%= item %></div>
            <% end %>
          </div>
        </div>

        <%= if p_selections && p_selections.open? do %>
          <div class="border-l border-r border-b rounded-b border-blue-planning-300">
            <%= for {size, %{values: values, open?: open?}} <- p_selections.selections do %>
              <.size_row size={size} values={values} open?={open?} myself={@myself} print_products_map={@print_products_map} product={product} />
              <%= for %{type: type, base_cost: base_cost} <- values, open? == true do %>
                  <div class="flex flex-col md:grid md:grid-cols-4 md:pl-12 md:py-2 cursor-pointer md:items-center hover:bg-blue-planning-100 md:border-none md:rounded-none m-6 rounded-lg border border-base-200">
                    <% final_cost = final_cost(@print_products_map, product.id, size, type) %>
                    <.pricing_card_mobile type={type} size={size} base_cost={base_cost} final_cost={final_cost} product={product} target={@myself}/>

                    <div class="font-bold hidden md:block"><%= split(type, "_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ") %> </div>
                    <div class="hidden md:block">$<%= sub(final_cost, base_cost) %></div>
                    <div class="hidden md:block"><%= base_cost %></div>
                    <% size_type = size <> type %>
                    <.form let={f} for={:size} phx-target={@myself} phx-change="final_cost" id={size_type <> "form"} class="flex items-center">
                      <%= for {name, value} <- [{:type, type}, {:product_id, product.id}, {:size, size}, {:base_cost, to_decimal(base_cost)}] do %>
                        <%= hidden_input f, name, value: value %>
                      <% end %>
                      <b class="md:hidden mr-3">Final Price</b>
                      <span class="w-24 md:w-44 border rounded-md border-blue-planning-300 pl-2" id="final_cost" data-input-id={"final_cost_#{size_type}"} data-span-id={size_type}, data-base-cost={to_decimal(base_cost)}, data-final-cost={final_cost} phx-hook="FinalCostInput">
                        <%= input f, :final_cost, step: "0.01", value: final_cost |> Decimal.round(2), phx_target: @myself, onkeydown: "return event.key != 'Enter';", id: "final_cost_#{size_type}", phx_hook: "PriceMask", class: "border-none bg-transparent top-0 left-1.5 w-full" %>
                      </span>
                      <span id={size_type} style="color: white;" class="text-[0.65rem] ml-1 md:w-auto w-20">must be greater than base cost</span>
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
           values: values
         } = assigns
       ) do
    details =
      Enum.map(values, fn %{type: type, base_cost: base_cost} ->
        final_cost = final_cost(print_products_map, product.id, size, type)
        %{final_cost: final_cost, profit: sub(final_cost, base_cost)}
      end)

    ~H"""
    <div class={"grid md:grid-cols-4 grid-cols-2 pl-6 py-3 border-b border-base-200 cursor-pointer #{if @open?, do: "bg-blue-planning-300"}"} phx-target={@myself} phx-click="expand_product_size" phx-value-size={size} phx-value-product_id={product.id}>
      <div class={"flex items-center font-bold pl-4 #{if @open?, do: "text-white", else: "text-black"}"}>
        <.icon name={if @open?, do: "up", else: "down"} class="w-3 h-3 stroke-current stroke-2 mr-4" />
        <%= split(size, "x") |> Enum.join(" x ") %>
      </div>
      <%= if !@open? do %>
        <div class="pl-6 text-base-250 hidden md:flex">From $<%= get_min(details, :profit) %></div>
        <div class="pl-4 text-base-250 hidden md:flex">From <%= get_min(values, :base_cost) %></div>
        <div class="pl-3 md:pl-0 text-base-250">From $<%= get_min(details, :final_cost) |> Decimal.round(2) %> </div>
      <% end %>
    </div>
    """
  end

  defp pricing_card_mobile(assigns) do
    ~H"""
      <div class={"font-bold md:hidden"}><%= split(@type, "_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ") %> </div>
      <hr class="my-2 md:hidden" />
      <div class="flex flex-row justify-between md:hidden">
        <div class="flex flex-col">
          <div class="flex my-2">
            <b class="mr-6">Your Profit</b>
            $<%= sub(@final_cost, @base_cost) %>
          </div>
          <div class="flex my-2">
            <b class="mr-6">Base Cost</b>
            <%= @base_cost %>
          </div>
        </div>
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
        "expand_product_all",
        %{"product-id" => product_id},
        %{assigns: %{selections: selections}} = socket
      ) do
    product_id = String.to_integer(product_id)

    selections
    |> update_in([product_id, :expand_all?], &(!&1))
    |> update_in(
      [product_id, :selections],
      &Enum.reduce(&1, %{}, fn {size, value}, acc ->
        Map.put(acc, size, %{value | open?: !value.open?})
      end)
    )
    |> update_in(
      [product_id, :selections],
      &Enum.sort_by(&1, fn {size, _value} ->
        [height, width] = split(size, "x")
        {to_integer(height), to_integer(width)}
      end)
    )
    |> then(&(socket |> assign(:selections, &1) |> noreply()))
  end

  @impl true
  def handle_event(
        "expand_product_size",
        %{"size" => size, "product_id" => product_id},
        %{assigns: %{selections: selections}} = socket
      ) do
    selections
    |> update_in([String.to_integer(product_id), :selections], &updater(&1, size))
    |> then(&(socket |> assign(:selections, &1) |> noreply()))
  end

  def handle_event(
        "final_cost",
        %{
          "size" => %{
            "final_cost" => final_cost,
            "product_id" => product_id,
            "size" => size,
            "type" => type,
            "base_cost" => base_cost
          }
        },
        %{assigns: %{print_products: print_products}} = socket
      ) do
    print_product = find(print_products, product_id, :product_id)
    final_cost = String.replace(final_cost, "$", "") |> String.replace(",", "")

    unless Decimal.lt?(new(final_cost), new(base_cost)) do
      print_product
      |> Map.get(:sizes)
      |> Enum.map(&build_params(&1, size, type, final_cost))
      |> then(&GlobalSettings.update_print_product!(print_product, %{sizes: &1}))
    end

    socket |> assign_print_products() |> noreply()
  end

  def assign_print_products(%{assigns: %{product: product}} = socket) do
    print_products = GlobalSettings.list_print_products(product.id)

    socket
    |> assign(
      :print_products_map,
      Map.new(
        print_products,
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
    |> Enum.sort_by(fn {size, _value} ->
      [height, width] = split(size, "x")
      {to_integer(height), to_integer(width)}
    end)
    |> then(&Map.put(selections, product.id, %{open?: true, selections: &1}))
  end

  defp process_product(%{open?: open?} = p_selections, selections, product) do
    Map.put(selections, product.id, %{p_selections | open?: !open?})
  end

  defp final_cost(print_products, product_id, size, type) do
    print_products
    |> Map.get(product_id)
    |> Map.get(size <> type)
    |> Map.get(:final_cost, new())
  end

  defp updater(selections, size_for_update) do
    Enum.map(selections, fn {size, value} ->
      open? = if size == size_for_update, do: !value.open?, else: value.open?
      {size, %{value | open?: open?}}
    end)
  end

  defp split(size, term), do: String.split(size, term, trim: true)
  defp sub(decimal, non_decimal), do: Decimal.sub(decimal || new(), to_decimal(non_decimal))

  defp find(list, id, key \\ :id), do: Enum.find(list, &(&1 |> Map.get(key) |> to_string() == id))
  defp get_min(details, key), do: Enum.min_by(details, & &1[key])[key]
  defp new(value \\ 0)
  defp new(""), do: new()
  defp new(value), do: Decimal.new(value)

  defdelegate to_decimal(value), to: GlobalSettings
end
