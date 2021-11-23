defmodule Picsello.Product do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query, only: [from: 2, join: 5, with_cte: 3, order_by: 3, select: 3]

  @attributes_cte """
  select
    attribute_categories.name as category_name,
    attribute_categories._id as category_id,
    attributes.id as id,
    attributes.name as name,
    attributes."pricingRefs" -> priced_attributes.id -> 'base' -> 'value' as price,
    priced_attributes.id as variation_id,
    priced_attributes.name as variation_name,
    cast(priced_attributes.metadata -> 'width' as integer) as width,
    cast(priced_attributes.metadata -> 'height' as integer) as height,
    products.id as product_id
  from
    products,
    jsonb_to_recordset(products.attribute_categories -> 0 -> 'attributes') as priced_attributes(id text, name text, metadata jsonb),
    jsonb_to_recordset(products.attribute_categories) as attribute_categories(attributes jsonb, name text, _id text),
    jsonb_to_recordset(attribute_categories.attributes) as attributes("pricingRefs" jsonb, name text, id text)
  where
    attributes."pricingRefs" -> priced_attributes.id is not null
  """

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
        markups.value
      )
      order by
        attributes.category_id,
        attributes.id
    ) as attributes
  from
    attributes
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
        height
    ) as variations
  from
    attributes_with_markups
  group by
    product_id
  """

  schema "products" do
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string
    field :attribute_categories, {:array, :map}
    field :variations, {:array, :map}, virtual: true

    belongs_to(:category, Picsello.Category)
    has_many(:markups, Picsello.Markup)

    timestamps(type: :utc_datetime)
  end

  def active, do: from(product in __MODULE__, where: is_nil(product.deleted_at))

  def with_attributes(query, %{organization_id: organization_id}) do
    query
    |> with_cte("attributes", as: fragment(@attributes_cte))
    |> with_cte("attributes_with_markups",
      as: fragment(@attributes_with_markups_cte, ^organization_id)
    )
    |> with_cte("variations", as: fragment(@variations_cte))
    |> join(:inner, [product], variation in "variations", on: variation.product_id == product.id)
    |> order_by([product], asc: product.position)
    |> select([product, variation], %{
      struct(product, [:whcc_name, :id])
      | variations: variation.variations
    })
  end
end
