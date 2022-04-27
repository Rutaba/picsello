defmodule Picsello.Repo.Migrations.AddBundlePriceToGalleryOrders do
  use Ecto.Migration

  def change do
    alter table(:gallery_orders) do
      add(:bundle_price, :integer)
    end
  end
end
