defmodule Picsello.Repo.Migrations.RemoveFieldFromProductLineItemsTable do
  use Ecto.Migration

  @table :product_line_items
  def up do
    alter table(@table) do
      remove(:round_up_to_nearest)
    end
  end

  def down do
    alter table(@table) do
      add(:round_up_to_nearest, :integer, null: false)
    end
  end
end
