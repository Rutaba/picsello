defmodule Picsello.Repo.Migrations.PromoteDigitalsToTable do
  use Ecto.Migration

  def up do
    execute("""
    create table digital_line_items (
      id bigserial primary key,
      photo_id bigint references photos not null,
      order_id bigint references gallery_orders not null,
      position int not null,
      price integer not null,
      inserted_at timestamp(0) without time zone not null,
      updated_at timestamp(0) without time zone not null
    )
    """)

    execute("""
    insert into
      digital_line_items (photo_id, order_id, position, price, inserted_at, updated_at) (
        select
          digitals.photo_id,
          id as order_id,
          row_number() over () as position,
          digitals.price,
          updated_at as inserted_at,
          updated_at
        from
          gallery_orders,
          jsonb_to_recordset(digitals) as digitals(price int, photo_id int)
      )
    """)

    execute("""
    alter table gallery_orders
      drop digitals,
      drop placed,
      drop shipping_cost,
      drop subtotal_cost
    """)
  end

  def down do
    execute("""
    alter table gallery_orders
      add column digitals jsonb default '[]' not null,
      add column placed boolean default false,
      add column shipping_cost integer not null default 0,
      add column subtotal_cost integer not null default 0
    """)

    execute("""
    with line_items as (
      select
        order_id,
        jsonb_build_object(
          'photo_id',
          photo_id,
          'price',
          price,
          'preview_url',
          preview_url,
          'id',
          (
            SELECT
              md5(concat(random(), clock_timestamp())) :: uuid
          )
        ) as digital
      from
        digital_line_items
        join photos on digital_line_items.photo_id = photos.id
      order by
        digital_line_items.position
    ),
    digitals as (
      select
        order_id,
        jsonb_agg(digital) as digitals
      from
        line_items
      group by
        order_id
    )
    update
      gallery_orders
    set
      digitals = digitals.digitals
    from
      digitals
    where
      gallery_orders.id = digitals.order_id
    """)

    execute("update gallery_orders set placed = true where placed_at is not null")

    execute("""
    update gallery_orders set shipping_cost = shipping_costs.cost
      from
        (select
          gallery_orders.id,
          sum(shipping.cost) as cost
        from
          gallery_orders
          join jsonb_to_recordset(products) as products(product jsonb) on true
          join lateral (
            select
              coalesce((product -> 'whcc_order' -> 'total') :: integer, 0) - coalesce((product -> 'base_price') :: integer, 0) as cost
          ) as shipping on true
        where
          shipping.cost > 0
        group by
          gallery_orders.id) as shipping_costs
      where gallery_orders.id = shipping_costs.id
    """)

    execute("""
    update gallery_orders set subtotal_cost = subtotals.subtotal_cost
      from
        (select
          gallery_orders.id,
          coalesce(sum(product_price :: integer), 0) + coalesce(sum(digitals.price), 0) as subtotal_cost
        from
          gallery_orders
          left join jsonb_path_query(products, '$[*].price') as product_price on true
          left join digital_line_items as digitals on digitals.order_id = gallery_orders.id
        group by
          gallery_orders.id) as subtotals
      where subtotals.id = gallery_orders.id
    """)

    drop(table("digital_line_items"))
  end
end
