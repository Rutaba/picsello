defmodule Picsello.Product do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query, only: [from: 2, join: 5, with_cte: 3, order_by: 3, select: 3]

  @product_attributes """
  select
    products.id as product_id,
    json_agg(
      jsonb_build_object(
        'variation_id', priced_attributes.id,
        'variation_name', priced_attributes.name,
        'category_name', attribute_categories.name,
        'category_id', attribute_categories._id,
        'attribute_id', attributes.id,
        'attribute_name', attributes.name,
        'price', attributes."pricingRefs" -> priced_attributes.id -> 'base' -> 'value'
      ) order by attributes.id, priced_attributes.metadata -> 'width', priced_attributes.metadata -> 'height'
    ) as attributes
  from
    products,
    jsonb_to_recordset(products.attribute_categories -> 0 -> 'attributes') as priced_attributes(id text, name text, metadata jsonb),
    jsonb_to_recordset(products.attribute_categories) as attribute_categories(attributes jsonb, name text, _id text),
    jsonb_to_recordset(attribute_categories.attributes) as attributes("pricingRefs" jsonb, name text, id text)
  where
    attributes."pricingRefs" -> priced_attributes.id is not null
  group by
    products.id
  """

  schema "products" do
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string
    field :attribute_categories, {:array, :map}
    field :attributes, {:array, :map}, virtual: true

    belongs_to(:category, Picsello.Category)

    timestamps(type: :utc_datetime)
  end

  def active, do: from(product in __MODULE__, where: is_nil(product.deleted_at))

  def with_attributes(query) do
    query
    |> with_cte("attributes", as: fragment(@product_attributes))
    |> join(:inner, [product], attribute in "attributes", on: attribute.product_id == product.id)
    |> order_by([product], asc: product.position)
    |> select([product, attribute], %{
      struct(product, [:whcc_name, :id])
      | attributes: attribute.attributes
    })
  end
end
