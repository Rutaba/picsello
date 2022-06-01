defmodule Picsello.Product do
  @moduledoc false
  use Ecto.Schema
  use StructAccess
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

  schema "products" do
    field :api, :map
    field :attribute_categories, {:array, :map}
    field :deleted_at, :utc_datetime
    field :position, :integer
    field :variations, {:array, :map}, virtual: true
    field :whcc_id, :string
    field :whcc_name, :string
    field :sizes, {:array, :map}, virtual: true

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
end
