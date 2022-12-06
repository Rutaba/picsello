defmodule Picsello.Repo.Migrations.ModifyPricingCalculations do
  use Ecto.Migration

  def change do
    alter table(:pricing_calculations) do
      modify(:state, :string, null: true, from: :string)
    end
  end
end
