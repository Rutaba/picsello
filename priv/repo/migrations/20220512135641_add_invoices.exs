defmodule Picsello.Repo.Migrations.AddInvoices do
  use Ecto.Migration

  def up do
    execute("""
    create table gallery_order_invoices (
      id bigserial primary key,
      amount_due integer not null,
      amount_paid integer not null,
      amount_remaining integer not null,
      description text not null,
      status text not null,
      stripe_id text not null,
      order_id bigint references gallery_orders not null,
      inserted_at timestamp(0) without time zone not null,
      updated_at timestamp(0) without time zone not null
    )
    """)

    execute("create unique index on gallery_order_invoices (order_id)")
  end

  def down do
    execute("drop table gallery_order_invoices")
  end
end
