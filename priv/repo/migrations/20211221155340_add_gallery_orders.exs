defmodule Picsello.Repo.Migrations.AddGalleryOrders do
  use Ecto.Migration

  def change do
    create table(:gallery_orders) do
      add(:number, :integer, null: false)
      add(:total_credits_amount, :integer, null: false)
      add(:subtotal_cost, :integer, null: false)
      add(:shipping_cost, :integer, null: false)
      add(:placed, :boolean, null: false)
      add(:products, {:array, :map})
      add(:digitals, {:array, :map})
      add(:delivery_info, :map)
      add(:gallery_id, references(:galleries, on_delete: :nothing), null: false)

      timestamps()
    end

    create index(:gallery_orders, [:gallery_id])
  end
end
