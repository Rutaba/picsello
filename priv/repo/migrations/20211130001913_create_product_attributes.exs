defmodule Picsello.Repo.Migrations.CreateProductAttributes do
  use Ecto.Migration

  def up do
    alter table("products") do
      add(:api, :map, null: false, default: fragment("'{}'"))
    end

    execute("""
      create materialized view product_attributes as (
    with attributes as (
    select
    products.id as product_id,
    attribute_categories._id as attribute_category_id,
    attribute_categories.name as attribute_category_name,
    attribute_categories.description as attribute_category_description,
    attribute_categories."parentCategory" as parent_attribute_category,
    attribute_categories."pricingRefsKey" as pricing_refs_key,
    attributes.id as id,
    attributes."childCategories" as child_categories,
    attributes.enabled,
    attributes."pricingRefs" as pricing_refs,
    (attributes.pricing -> 'base' -> 'value') :: float as price,
    attributes.image,
    attributes.name,
    (attributes.metadata -> 'width') :: int as width,
    (attributes.metadata -> 'height') :: int as height
    from
    products
    join jsonb_to_recordset(products.attribute_categories) as attribute_categories(
      attributes jsonb,
      name text,
      _id text,
      description text,
      "parentCategory" text,
      "pricingRefsKey" jsonb
    ) on true
    join jsonb_to_recordset(attribute_categories.attributes) as attributes(
      enabled boolean,
      "pricingRefs" jsonb,
      pricing jsonb,
      image text,
      "childCategories" jsonb,
      name text,
      metadata jsonb,
      id text
    ) on true
    ),
    ref_prices as (
    select
    (refs.value -> 'base' -> 'value') :: float as price,
    product_id,
    keys.keys as priced_attribute_category_id,
    attributes.pricing_refs_key -> 'keys',
    attributes.id as attribute_id,
    attribute_category_id,
    split_part(
      refs.key,
      pricing_refs_key ->> 'separator',
      array_position(key_arrays.array, keys.keys)
    ) as priced_attribute_id,
    refs.key as id
    from
    attributes
    join jsonb_each(attributes.pricing_refs) as refs on true
    join lateral (
      select
        array_agg(value) as array
      from
        jsonb_array_elements_text(attributes.pricing_refs_key -> 'keys')
    ) as key_arrays on true
    join unnest(key_arrays.array) as keys on true
    where
    attributes.pricing_refs is not null
    ),
    ref_attributes as (
    select
    ref_prices.product_id,
    string_agg(
      priced_attributes.attribute_category_name,
      ' and '
      order by
        priced_attributes.attribute_category_name
    ) as variation_category_name,
    string_agg(
      priced_attributes.name,
      ', '
      order by
        priced_attributes.name
    ) as variation_name,
    string_agg(
      distinct priced_attributes.id,
      ''
      order by
        priced_attributes.id
    ) as variation_id,
    string_agg(distinct attributes.attribute_category_name, '') as category_name,
    string_agg(
      distinct attributes.attribute_category_id,
      ''
      order by
        attributes.attribute_category_id
    ) as category_id,
    string_agg(distinct attributes.name, '') as name,
    string_agg(
      distinct attributes.id,
      ''
      order by
        attributes.id
    ) as id,
    sum(coalesce(priced_attributes.width, 0)) as width,
    sum(coalesce(priced_attributes.height, 0)) as height,
    round(ref_prices.price * 100) as price
    from
    ref_prices
    join attributes on ref_prices.attribute_id = attributes.id
    and ref_prices.product_id = attributes.product_id
    and ref_prices.attribute_category_id = attributes.attribute_category_id
    join attributes as priced_attributes on ref_prices.priced_attribute_id = priced_attributes.id
    and ref_prices.product_id = priced_attributes.product_id
    and ref_prices.priced_attribute_category_id = priced_attributes.attribute_category_id
    group by
    ref_prices.product_id,
    ref_prices.attribute_category_id,
    ref_prices.attribute_id,
    ref_prices.id,
    ref_prices.price
    ),
    price_attributes as (
    select
    product_id,
    null as variation_category_name,
    attribute_category_name as variation_name,
    attribute_category_id as variation_id,
    attribute_category_name as category_name,
    attribute_category_id as category_id,
    name,
    id,
    width,
    height,
    round(price * 100) as price
    from
    attributes
    where
    price is not null
    )
    select
    *
    from
    ref_attributes
    union
    select
    *
    from
    price_attributes
    )
    """)
  end

  def down do
    execute("drop materialized view product_attributes")

    alter table("products") do
      remove(:api)
    end
  end
end
