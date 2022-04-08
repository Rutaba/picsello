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

  defmodule LineItem do
    use Ecto.Schema

    embedded_schema do
      field(:yearly_cost, Money.Ecto.Amount.Type)
      field(:title, :string)
      field(:description, :string)
    end
  end

  defmodule BusinessCost do
    use Ecto.Schema

    embedded_schema do
      field(:category, :string)
      field(:active, :boolean)
      field(:description, :string)
      embeds_many(:line_items, LineItem)
    end
  end

  defmodule PricingSuggestions do
    use Ecto.Schema

    embedded_schema do
      field(:job_type, :string)
      field(:description, :string)
      field(:yearly_cost, Money.Ecto.Amount.Type)
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
    |> cast_embed(:business_costs, with: &business_cost_changeset(&1, &2))
  end

  defp business_cost_changeset(business_cost, attrs) do
    business_cost
    |> cast(attrs, [:category, :active, :description])
    |> cast_embed(:line_items, with: &line_items_changeset(&1, &2))
  end

  defp line_items_changeset(line_item, attrs) do
    line_item
    |> cast(attrs, [:yearly_cost, :title, :description])
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

  def compare_income_bracket(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          income_max: %Money{amount: income_max},
          income_min: %Money{amount: income_min}
        },
        desired_salary_text
      ) do
    {:ok, value} = Money.parse(desired_salary_text)
    %Money{amount: desired_salary} = value

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
        %Money{} = desired_salary
      ) do
    taxes_owed =
      desired_salary
      |> Money.subtract(fixed_cost_start)
      |> Money.multiply(Decimal.div(percentage, 100))
      |> Money.add(fixed_cost)

    desired_salary |> Money.subtract(taxes_owed)
  end

  def calculate_after_tax_income(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          fixed_cost_start: fixed_cost_start,
          fixed_cost: fixed_cost,
          percentage: percentage
        },
        desired_salary_text
      ) do
    {:ok, desired_salary} = Money.parse(desired_salary_text)

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

  def calculate_monthly(%Money{amount: amount}) do
    Money.new(div(amount, 12))
  end

  def calculate_monthly(amount) do
    {:ok, money} = Money.parse(amount, :USD)
    %Money{amount: finalAmount} = money

    Money.new(div(finalAmount, 12))
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
    do:
      PricingCalculatorBusinessCosts
      |> Repo.all()
      |> Enum.map(&new_map(&1))

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

  defp new_map(
         %{
           line_items: line_items,
           category: category,
           active: active,
           description: description
         } = _business_cost
       ) do
    %Picsello.PricingCalculations.BusinessCost{
      category: category,
      line_items:
        line_items
        |> Enum.map(&struct(LineItem, Map.from_struct(&1))),
      active: active,
      description: description
    }
  end

  def calculate_revenue(
        take_home,
        costs
      ) do
    Money.add(take_home, costs)
  end

  def calculate_all_costs(business_costs) do
    business_costs
    |> Enum.map(fn %{line_items: line_items} ->
      line_items |> calculate_costs_by_category() |> Map.get(:amount)
    end)
    |> total_business_cost()
    |> Money.new()
  end

  def calculate_costs_by_category(line_items) do
    line_items
    |> Enum.map(fn %{yearly_cost: %Money{amount: amount}} -> amount end)
    |> total_business_cost()
    |> Money.new()
  end

  def calculate_costs_by_category(_line_items, %{"line_items" => line_items} = _params) do
    line_items
    |> Enum.map(fn {_k, %{"yearly_cost" => yearly_cost}} ->
      Money.parse(yearly_cost, :USD) |> elem(1) |> Map.get(:amount)
    end)
    |> total_business_cost()
    |> Money.new()
  end

  def calculate_costs_by_category(line_items, %{} = _params) do
    line_items
    |> Enum.map(fn %{yearly_cost: %Money{amount: amount}} -> amount end)
    |> total_business_cost()
    |> Money.new()
  end

  def total_business_cost(list), do: recursively_add_business_cost(list, 0)

  defp recursively_add_business_cost([], acc), do: acc
  defp recursively_add_business_cost([h | t], acc), do: recursively_add_business_cost(t, acc + h)
end
