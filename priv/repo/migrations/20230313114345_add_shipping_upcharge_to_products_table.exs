defmodule Picsello.Repo.Migrations.AddShippingUpchargeToProductsTable do
  use Ecto.Migration

  @table :products
  def up do
    alter table(@table) do
      add(:shipping_upcharge, :map, default: %{default: 0})
    end
  end

  def down do
    alter table(@table) do
      remove(:shipping_upcharge)
    end
  end
end
