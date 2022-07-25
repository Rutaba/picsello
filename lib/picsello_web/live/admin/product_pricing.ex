defmodule PicselloWeb.Live.Admin.ProductPricing do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  @uniquely_priced_selections """
  with
   attribute_categories as (
    select
      products.id as product_id,
      _id as category_id,
      attributes.id as attribute_id,
      "pricingRefs" as pricing_refs,
      pricing
    from
      products,
      jsonb_to_recordset(products.attribute_categories) as attribute_categories(attributes jsonb, _id text, "pricingRefsKey" jsonb),
      jsonb_to_recordset(attribute_categories.attributes) as attributes(
        id text,
        "pricingRefs" jsonb,
        "pricing" jsonb,
        metadata jsonb
      )
    where
      attribute_categories."pricingRefsKey" is not null
      or attributes.pricing is not null
      or jsonb_path_exists(
        products.attribute_categories,
        '$[*].pricingRefsKey.keys ? (exists(@[*] ? (@ == $category_id)))',
        jsonb_build_object('category_id', _id)
      )
  ),
  keyed_attribute_categories as (
    select
      product_id,
      category_id,
      attribute_id,
      jsonb_object_agg(refs.key, refs.value -> 'base' -> 'value') as pricing_key
    from
      attribute_categories,
      jsonb_each(pricing_refs) as refs
    group by
      1,
      2,
      3
  union
    select
      product_id,
      category_id,
      attribute_id,
      pricing -> 'base' -> 'value' as pricing_key
    from
      attribute_categories
    where
      pricing is not null and pricing_refs is null
  union
    select
      product_id,
      category_id,
      attribute_id,
      jsonb_build_object('id', attribute_id) as pricing_key
    from
      attribute_categories
    where
      pricing is null
      and pricing_refs is null
  )
  select
    category_id,
    (array_agg(attribute_id)) [1] as attribute_id,
    string_agg(attribute_id, ', ') as name
  from
    keyed_attribute_categories
  where product_id = $1
  group by
    category_id,
    pricing_key
  """

  import Ecto.Query, only: [from: 2]
  alias Picsello.{Category, Product, Repo}

  def mount(_, _, socket) do
    socket
    |> assign(
      categories: from(category in Category, preload: :products, order_by: :name) |> Repo.all()
    )
    |> ok()
  end

  def handle_params(%{"id" => product_id}, _uri, socket) do
    product = Repo.get!(Product, product_id) |> Repo.preload(:category)

    {category_names, rows} = rows(product)

    socket
    |> assign(
      product: product,
      attribute_category_names: category_names,
      rows: rows
    )
    |> noreply()
  end

  def handle_params(_, _uri, socket), do: socket |> assign(product: nil) |> noreply()

  def render(assigns) do
    ~H"""
      <ul class="flex p-8 border justify-evenly">
        <%= for %{name: name, products: [_|_] = products} <- @categories do %>
          <li>
            <%= name %>

            <ul class="pl-4 list-disc">
              <%= for %{whcc_name: name, id: id} <- products do %>
                <li>
                  <%= live_patch to: Routes.admin_product_pricing_path(@socket, :show, id) do %>
                    <%= name %>
                  <% end %>
                </li>
              <% end %>
            </ul>
          </li>
        <% end %>
      </ul>

      <%= if @product do %>
        <div class="flex items-center p-8">
          <h1 class="mr-4 text-lg font-bold"><%= @product.whcc_name %></h1>
          <p><%= @product.api |> Map.get("description") %></p>
        </div>

        <table class="mx-8 mb-8">
          <thead class="bg-base-200">
            <tr>
              <th colspan="5" class="p-2 border">pricing</th>
              <th colspan={length @attribute_category_names} class="p-2 border">selections</th>
            </tr>

            <tr>
              <th class="p-2 border">client price</th>
              <th class="p-2 border">whcc - shipping total</th>
              <th class="p-2 border">whcc - print cost</th>
              <th class="p-2 border">user - markup</th>
              <th class="p-2 border">user - rounding</th>

              <%= for name <- @attribute_category_names do %>
                <th><%= name %></th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @rows do %>
              <tr>
                <%= for value <- row do %>
                  <td class="p-2 text-right border"><%= value %></td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    """
  end

  defp rows(%{attribute_categories: attribute_categories} = product) do
    selections = selections(product)

    categories = multi_value_categories(selections)

    rows =
      for row_with_names <- selections do
        row = for({k, %{id: id}} <- row_with_names, into: %{}, do: {k, id})

        unit_price = selection_unit_price(product, row)

        %{
          shipping_base_charge: shipping_base,
          unit_markup: markup,
          shipping_upcharge: shipping_upcharge
        } =
          product =
          product
          |> Picsello.WHCC.price_details(%{selections: row}, %{
            unit_base_price: unit_price,
            quantity: 1
          })
          |> Picsello.Cart.Product.new()

        client_price = Picsello.Cart.Product.example_price(product)

        [
          client_price,
          Money.add(shipping_base, Money.multiply(unit_price, shipping_upcharge)),
          unit_price,
          markup,
          Money.subtract(
            client_price,
            Picsello.Cart.Product.example_price(%{product | round_up_to_nearest: 1})
          )
        ] ++
          for(category_id <- categories, do: get_in(row_with_names, [category_id, :name]))
      end

    {Enum.map(categories, fn id ->
       attribute_categories |> Enum.find(&(Map.get(&1, "_id") == id)) |> Map.get("name")
     end), Enum.sort_by(rows, &Enum.at(&1, 2))}
  end

  defp multi_value_categories(selections) do
    for selection <- selections, reduce: %{} do
      acc ->
        Map.merge(acc, selection, fn
          _k, v1, v2 when is_list(v1) -> [v2 | v1]
          _k, v1, v2 -> [v1, v2]
        end)
    end
    |> Enum.filter(&(&1 |> elem(1) |> Enum.uniq() |> length > 1))
    |> Enum.into(%{})
    |> Map.keys()
  end

  defp selections(%{id: product_id}) do
    %{rows: rows} = Ecto.Adapters.SQL.query!(Repo, @uniquely_priced_selections, [product_id])

    name_map =
      Enum.group_by(rows, &hd/1, &tl/1)
      |> Enum.map(fn {category_id, values} ->
        {category_id, values |> Enum.map(&List.to_tuple/1) |> Enum.into(%{})}
      end)
      |> Enum.into(%{})

    for({category_id, attributes} <- name_map, do: {category_id, Map.keys(attributes)})
    |> do_selections()
    |> Enum.map(fn selection ->
      Enum.map(selection, fn {category_id, attribute_id} ->
        {category_id, %{id: attribute_id, name: get_in(name_map, [category_id, attribute_id])}}
      end)
      |> Enum.into(%{})
    end)
  end

  defp do_selections([{key, values}]), do: for(value <- values, do: [{key, value}])

  defp do_selections([{key, values} | tail]),
    do: for(selections <- do_selections(tail), value <- values, do: [{key, value} | selections])

  defdelegate selection_unit_price(product, selection), to: Picsello.WHCC.Product
end
