defmodule Picsello.Repo.Migrations.AddNewFieldToProductLineItems do
  use Ecto.Migration

  def change do
    alter table(:product_line_items) do
      add(:das_carrier_cost, :integer)
    end
  end
end
