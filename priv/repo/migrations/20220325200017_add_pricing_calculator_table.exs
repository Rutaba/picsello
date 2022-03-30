defmodule Picsello.Repo.Migrations.AddPricing do
  use Ecto.Migration

  def change do
    create table(:pricing_calculations) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:average_time_per_week, :integer, null: false)
      add(:average_days_per_week, {:array, :string})
      add(:desired_salary, :integer, null: false)
      add(:tax_bracket, :integer, null: false)
      add(:after_income_tax, :integer, null: false)
      add(:self_employment_tax, :integer, null: false)
      add(:take_home, :integer, null: false)
      add(:job_types, references(:job_types, column: :name, type: :string), null: false)
      add(:full_time, :boolean, null: false)
      add(:min_years_experience, :integer, null: false)

      add(:state, references(:cost_of_living_adjustments, column: :state, type: :string),
        null: false
      )

      add(:business_costs, :map, null: false, default: fragment("'[]'::jsonb"))
      add(:pricing_suggestions, :map, null: false, default: fragment("'[]'::jsonb"))

      timestamps()
    end
  end
end
