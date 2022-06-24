defmodule Picsello.Repo.Migrations.FixJsonArrays do
  use Ecto.Migration

  def up do
    rename(table("gallery_orders"), :products, to: :old_products)
    rename(table("gallery_orders"), :digitals, to: :old_digitals)

    alter table("gallery_orders") do
      add(:products, :map, null: false, default: "[]")
      add(:digitals, :map, null: false, default: "[]")
    end

    execute("""
      update gallery_orders set products = products_json, digitals = digitals_json
      from (
        select
        id,
        coalesce(jsonb_agg(unnested_products) filter (where unnested_products is not null), '[]'::jsonb) as products_json,
        coalesce(jsonb_agg(unnested_digitals) filter (where unnested_digitals is not null), '[]'::jsonb) as digitals_json
        from
        gallery_orders
        left join unnest(old_products) as unnested_products on true
        left join unnest(old_digitals) as unnested_digitals on true
        group by id
      ) as jsonified where jsonified.id = gallery_orders.id
    """)

    alter table("gallery_orders") do
      remove(:old_products)
      remove(:old_digitals)
    end
  end

  def down do
    rename(table("gallery_orders"), :products, to: :old_products)
    rename(table("gallery_orders"), :digitals, to: :old_digitals)

    alter table("gallery_orders") do
      add(:products, {:array, :map})
      add(:digitals, {:array, :map})
    end

    execute("""
      update gallery_orders set products = products_array, digitals = digitals_array
      from (
        select
          id,
          coalesce(array_agg(json_products) filter (where json_products is not null), '{}') as products_array,
          coalesce(array_agg(json_digitals) filter (where json_digitals is not null), '{}') as digitals_array
        from
          gallery_orders
          left join jsonb_array_elements(old_products) as json_products on true
          left join jsonb_array_elements(old_digitals) as json_digitals on true
        group by
          id
      ) as jsonified where jsonified.id = gallery_orders.id
    """)

    alter table("gallery_orders") do
      remove(:old_products)
      remove(:old_digitals)
    end
  end
end
