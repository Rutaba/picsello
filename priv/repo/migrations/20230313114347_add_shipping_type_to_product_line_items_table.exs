defmodule Picsello.Repo.Migrations.AddShippingTypeToProductLineItemsTable do
  use Ecto.Migration

  @table :product_line_items
  def up do
    alter table(@table) do
      add(:shipping_type, :string)
      modify(:shipping_base_charge, :integer, null: true)
      modify(:shipping_upcharge, :numeric, null: true)
    end
  end

  def down do
    alter table(@table) do
      remove(:shipping_type)
      modify(:shipping_base_charge, :integer, null: false)
      modify(:shipping_upcharge, :numeric, null: false)
    end
  end
end
