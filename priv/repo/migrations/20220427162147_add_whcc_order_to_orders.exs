defmodule Picsello.Repo.Migrations.AddWhccOrderToOrders do
  use Ecto.Migration

  def up do
    execute("""
      alter table gallery_orders add column whcc_order jsonb
    """)
  end

  def down do
    execute("""
      alter table gallery_orders drop column whcc_order
    """)
  end
end
