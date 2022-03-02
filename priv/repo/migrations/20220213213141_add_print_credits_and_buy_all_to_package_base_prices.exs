defmodule Picsello.Repo.Migrations.AddPrintCreditsToPackageBasePrices do
  use Ecto.Migration

  def change do
    alter table("package_base_prices") do
      add(:print_credits, :integer)
      add(:buy_all, :integer)
    end
  end
end
