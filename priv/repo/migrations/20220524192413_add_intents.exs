defmodule Picsello.Repo.Migrations.AddIntents do
  use Ecto.Migration

  def up do
    execute("""
    create table gallery_order_intents (
      id bigserial primary key,
      amount integer not null,
      amount_received integer not null,
      amount_capturable integer not null,
      application_fee_amount integer not null,
      description text not null,
      status text not null,
      stripe_id text not null,
      order_id bigint references gallery_orders not null,
      inserted_at timestamp(0) without time zone not null,
      updated_at timestamp(0) without time zone not null
    )
    """)

    execute("create unique index on gallery_order_intents (order_id)")
    execute("create unique index on gallery_order_intents (stripe_id)")
  end

  def down do
    execute("drop table gallery_order_intents")
  end
end
