defmodule Picsello.Product do
  @moduledoc false
  use Ecto.Schema
  use StructAccess
  alias Picsello.Repo
  import Ecto.Query, only: [from: 2, join: 5, with_cte: 3, order_by: 3, select: 3]

  @attributes_with_markups_cte """
  select
    height,
    attributes.product_id,
    variation_id,
    variation_name,
    width,
    jsonb_agg(
      jsonb_build_object(
        'category_name',
        attributes.category_name,
        'category_id',
        attributes.category_id,
        'id',
        attributes.id,
        'name',
        attributes.name,
        'price',
        attributes.price,
        'markup',
        coalesce(markups.value, ?)
      )
      order by
        attributes.category_id,
        attributes.id
    ) as attributes
  from
    product_attributes as attributes
    left outer join markups on markups.product_id = attributes.product_id
    and markups.whcc_attribute_category_id = category_id
    and markups.whcc_variation_id = attributes.variation_id
    and markups.whcc_attribute_id = attributes.id
    and markups.organization_id = ?
  group by
    attributes.product_id,
    height,
    variation_id,
    variation_name,
    width
  """

  @variations_cte """
  select
    product_id,
    jsonb_agg(
      jsonb_build_object(
        'id',
        variation_id,
        'name',
        variation_name,
        'attributes',
        attributes
      )
      order by
        width,
        height,
        variation_id
    ) as variations
  from
    attributes_with_markups
  group by
    product_id
  """
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

  schema "products" do
    field :api, :map
    field :attribute_categories, {:array, :map}
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :variations, {:array, :map}, virtual: true
    field :whcc_id, :string
    field :whcc_name, :string
    field :sizes, {:array, :map}, virtual: true
    field :shipping_upcharge, :map

    belongs_to(:category, Picsello.Category)
    has_many(:markups, Picsello.Markup)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  def active, do: from(product in __MODULE__, where: is_nil(product.deleted_at))

  def whcc_category(%__MODULE__{api: %{"category" => category}}),
    do: Picsello.WHCC.Category.from_map(category)

  def with_attributes(query, %{organization_id: organization_id}) do
    default_markup = Picsello.Markup.default_markup()

    query
    |> with_cte("attributes_with_markups",
      as: fragment(@attributes_with_markups_cte, ^default_markup, ^organization_id)
    )
    |> with_cte("variations", as: fragment(@variations_cte))
    |> join(:inner, [product], variation in "variations", on: variation.product_id == product.id)
    |> order_by([product], asc: product.position)
    |> select([product, variation], %{
      struct(product, [:whcc_name, :id])
      | variations: variation.variations
    })
  end

  def selections_with_prices(product) do
    selections = selections(product)

    categories = multi_value_categories(selections)

    rows =
      for row_with_names <- selections do
        row = for({k, %{id: id}} <- row_with_names, into: %{}, do: {k, id})

        unit_price = Picsello.WHCC.Product.selection_unit_price(product, row)

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

    {categories, rows}
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
end
