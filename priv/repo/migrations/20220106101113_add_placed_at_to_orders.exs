defmodule Picsello.Repo.Migrations.AddPlacedAtToOrders do
  use Ecto.Migration

  def change do
    alter table(:gallery_orders) do
      add(:placed_at, :utc_datetime)
    end
  end
end
