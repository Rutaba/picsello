defmodule Picsello.Repo.Migrations.AddUnitBasePriceToProductsTable do
  use Ecto.Migration

  @table :product_line_items
  def up do
    alter table(@table) do
      add(:unit_base_price, :integer, null: true)
    end

    execute("""
    UPDATE product_line_items
    SET unit_base_price = product_line_items.unit_price
    where unit_base_price is NULL
    """)
  end

  def down do
    alter table(@table) do
      remove(:shipping_type)
      remove(:total_markuped_price)
    end

    execute("""
    UPDATE product_line_items
    SET unit_base_price = Null
    """)
  end
end
