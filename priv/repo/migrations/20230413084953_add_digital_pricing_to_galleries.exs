defmodule Picsello.Repo.Migrations.AddDigitalPricingToGalleries do
  use Ecto.Migration

  def up do
    alter table(:galleries) do
      add(:digital_pricing, :map)
    end
  end

  def down do
    alter table(:galleries) do
      remove(:digital_pricing)
    end
  end
end
