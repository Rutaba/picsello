defmodule Picsello.PricingCalculations do
  alias Picsello.{
    Repo,
    Organization,
    PricingCalculatorTaxSchedules,
    PricingCalculatorBusinessCosts
  }

  import Ecto.Changeset
  import Ecto.Query

  use Ecto.Schema

  defmodule BusinessCost do
    use Ecto.Schema

    embedded_schema do
      field(:title, :string)
      field(:yearly_cost, :integer)
    end
  end

  defmodule PricingSuggestions do
    use Ecto.Schema

    embedded_schema do
      field(:job_type, :string)
      field(:description, :string)
      field(:yearly_cost, :integer)
    end
  end

  @days_of_the_week [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
  ]

  schema "pricing_calculations" do
    belongs_to(:organization, Organization)
    field(:average_time_per_week, :integer)

    field(:average_days_per_week, {:array, :string}, values: @days_of_the_week)

    field(:desired_salary, Money.Ecto.Amount.Type)
    field(:tax_bracket, :integer)
    field(:after_income_tax, Money.Ecto.Amount.Type)
    field(:self_employment_tax_percentage, :decimal)
    field(:take_home, Money.Ecto.Amount.Type)
    field(:job_types, {:array, :string})
    field(:schedule, :string)
    field(:min_years_experience, :integer)
    field(:state, :string)
    field(:zipcode, :string)
    embeds_many(:business_costs, BusinessCost)
    embeds_many(:pricing_suggestions, PricingSuggestions)

    timestamps(type: :utc_datetime)
  end

  def changeset(%Picsello.PricingCalculations{} = pricing_calculations, attrs) do
    pricing_calculations
    |> cast(attrs, [
      :organization_id,
      :job_types,
      :state,
      :min_years_experience,
      :schedule,
      :zipcode,
      :average_days_per_week,
      :average_time_per_week,
      :desired_salary,
      :self_employment_tax_percentage,
      :tax_bracket,
      :take_home
    ])
  end

  def compare_income_bracket(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          income_max: %Money{amount: income_max},
          income_min: %Money{amount: income_min}
        },
        %Money{amount: desired_salary}
      ) do
    cond do
      income_max == 0 ->
        income_min <= desired_salary

      income_min == 0 ->
        desired_salary < income_max

      true ->
        income_min <= desired_salary and desired_salary < income_max
    end
  end

  def get_income_bracket(value) do
    %{income_brackets: income_brackets} = tax_schedule()

    income_brackets
    |> Enum.filter(fn bracket -> compare_income_bracket(bracket, value) end)
    |> Enum.at(0)
  end

  def calculate_after_tax_income(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          fixed_cost_start: fixed_cost_start,
          fixed_cost: fixed_cost,
          percentage: percentage
        },
        desired_salary
      ) do
    taxes_owed =
      desired_salary
      |> Money.subtract(fixed_cost_start)
      |> Money.multiply(Decimal.div(percentage, 100))
      |> Money.add(fixed_cost)

    desired_salary |> Money.subtract(taxes_owed)
  end

  def calculate_take_home_income(percentage, after_tax_income) do
    taxes_owed =
      after_tax_income
      |> Money.multiply(Decimal.div(percentage, 100))

    after_tax_income |> Money.subtract(taxes_owed)
  end

  def day_options(),
    do: [
      "monday",
      "tuesday",
      "wednesday",
      "thursday",
      "friday",
      "saturday",
      "sunday"
    ]

  def cost_categories(),
    do: PricingCalculatorBusinessCosts |> Repo.all()

  def tax_schedule(),
    do: Repo.get_by(PricingCalculatorTaxSchedules, active: true)

  def state_options(),
    do:
      from(adjustment in Picsello.Packages.CostOfLivingAdjustment,
        select: adjustment.state,
        order_by: adjustment.state
      )
      |> Repo.all()
      |> Enum.map(&{&1, &1})
end
