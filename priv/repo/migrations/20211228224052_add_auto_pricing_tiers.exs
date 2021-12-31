defmodule Picsello.Repo.Migrations.AddAutoPricingTiers do
  use Ecto.Migration

  def change do
    create table(:package_tiers, primary_key: false) do
      add(:name, :string, primary_key: true)
      add(:position, :integer, null: false)
    end

    create table(:package_base_prices) do
      add(:tier, references(:package_tiers, column: :name, type: :string))
      add(:job_type, references(:job_types, column: :name, type: :string))
      add(:full_time, :boolean, null: false)
      add(:min_years_experience, :integer, null: false)
      add(:base_price, :integer, null: false)
    end

    create(
      unique_index(:package_base_prices, [:tier, :job_type, :full_time, :min_years_experience])
    )

    create table(:cost_of_living_adjustments, primary_key: false) do
      add(:state, :string, primary_key: true)
      add(:multiplier, :decimal, null: false)
    end
  end
end
