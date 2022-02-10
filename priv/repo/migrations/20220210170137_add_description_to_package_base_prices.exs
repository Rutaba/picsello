defmodule Picsello.Repo.Migrations.AddDescriptionToPackageBasePrices do
  use Ecto.Migration

  def change do
    alter table(:package_base_prices) do
      add(:description, :text)
    end
  end
end
