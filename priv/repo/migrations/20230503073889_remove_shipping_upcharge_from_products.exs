defmodule Picsello.Repo.Migrations.RemoveShippingUpchargeFromProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      remove(:shipping_upcharge)
    end
  end
end
