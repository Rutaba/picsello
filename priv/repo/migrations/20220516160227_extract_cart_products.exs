defmodule Picsello.Repo.Migrations.ExtractCartProducts do
  use Ecto.Migration

  def up do
    execute("""
      create table product_line_items (
        id bigserial primary key,

        editor_id text not null,
        preview_url text not null,
        price integer not null,
        print_credit_discount integer not null,
        quantity integer not null,
        round_up_to_nearest integer not null,
        selections jsonb not null,
        shipping_base_charge integer not null,
        shipping_upcharge numeric not null,
        unit_markup integer not null,
        unit_price integer not null,
        volume_discount integer not null,

        order_id bigint references gallery_orders not null,
        whcc_product_id bigint references products not null,

        inserted_at timestamp(0) without time zone not null,
        updated_at timestamp(0) without time zone not null
      )
    """)

    execute("""
      insert into
        product_line_items (
          order_id,
          editor_id,
          preview_url,
          quantity,
          round_up_to_nearest,
          selections,
          shipping_base_charge,
          shipping_upcharge,
          unit_markup,
          unit_price,
          whcc_product_id,
          volume_discount,
          print_credit_discount,
          price,
          inserted_at,
          updated_at
        ) (
          select
            gallery_orders.id as order_id,
            product_line_items.editor_details ->> 'editor_id' as editor_id,
            product_line_items.editor_details ->> 'preview_url' as preview_url,
            quantity,
            round_up_to_nearest,
            product_line_items.editor_details -> 'selections' as selections,
            shipping_base_charge,
            shipping_upcharge,
            unit_markup,
            unit_price,
            products.id as whcc_product_id,
            0,
            0,
            0,
            to_timestamp(created_at / 1000) at time zone 'utc' as inserted_at,
            to_timestamp(created_at / 1000) at time zone 'utc' as updated_at
          from
            gallery_orders
            join jsonb_to_recordset(gallery_orders.products) as product_line_items(
              created_at numeric,
              editor_details jsonb,
              quantity int,
              round_up_to_nearest int,
              shipping_base_charge int,
              shipping_upcharge numeric,
              unit_markup int,
              unit_price int
            ) on true
            join products on products.whcc_id = (product_line_items.editor_details ->> 'product_id')
        )
    """)

    execute("""
    alter table digital_line_items
      add column is_credit boolean default false,
      drop column position
    """)

    execute("""
    update
      digital_line_items
    set price = package_prices.price, is_credit = digital_line_items.price = 0
    from
    (
      select
        packages.download_each_price as price,
        digital_line_items.id as digital_id
      from
        packages
        join jobs on jobs.package_id = packages.id
        join galleries on galleries.job_id = jobs.id
        join gallery_orders on gallery_orders.gallery_id = galleries.id
        join digital_line_items on digital_line_items.order_id = gallery_orders.id
    ) as package_prices
    where
      digital_line_items.id = package_prices.digital_id;
    """)

    execute("alter table gallery_orders drop column products")

    execute("create unique index on digital_line_items (order_id, photo_id)")
  end

  def down do
    execute("alter table gallery_orders add column products jsonb not null default '[]'")

    execute("""
    alter table digital_line_items
    drop column is_credit,
    add column position integer not null default 0
    """)

    execute("""
      update
        gallery_orders
      set
        products = aggregated_products.products
      from
        (
          with order_products as (
            select
              order_id,
              jsonb_build_object(
                'created_at',
                extract(
                  epoch
                  from
                    product_line_items.inserted_at
                ) * 1000,
                'editor_details',
                jsonb_build_object(
                  'preview_url',
                  preview_url,
                  'editor_id',
                  editor_id,
                  'product_id',
                  products.whcc_id,
                  'selections',
                  selections
                ),
                'unit_markup',
                unit_markup,
                'quantity',
                quantity,
                'round_up_to_nearest',
                round_up_to_nearest,
                'shipping_base_charge',
                shipping_base_charge,
                'shipping_upcharge',
                shipping_upcharge,
                'unit_price',
                unit_price
              ) as json
            from
              product_line_items
              join products on product_line_items.whcc_product_id = products.id
          )
          select
            order_id,
            jsonb_agg(
              json
              order by
                (json -> 'created_at') :: bigint desc
            ) as products
          from
            order_products
          group by
            order_id
        ) as aggregated_products
      where
        aggregated_products.order_id = gallery_orders.id
    """)

    execute("drop table product_line_items")
  end
end
