defmodule Picsello.Repo.Migrations.AddPricing do
  use Ecto.Migration

  def change do
    create table(:pricing_calculations) do
      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:average_time_per_week, :integer)
      add(:average_days_per_week, {:array, :string})
      add(:desired_salary, :integer)
      add(:tax_bracket, :integer)
      add(:after_income_tax, :integer)
      add(:self_employment_tax, :integer)
      add(:take_home, :integer)
      add(:job_types, {:array, :string})
      add(:schedule, :string)
      add(:min_years_experience, :integer)
      add(:zipcode, :string)

      add(:state, references(:cost_of_living_adjustments, column: :state, type: :string),
        null: false
      )

      add(:business_costs, :map, default: fragment("'[]'::jsonb"))
      add(:pricing_suggestions, :map, default: fragment("'[]'::jsonb"))

      timestamps()
    end
  end
end
