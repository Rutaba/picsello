defmodule Picsello.PricingCalculations do
  @moduledoc false
  alias Picsello.{
    Repo,
    Organization,
    PricingCalculatorTaxSchedules,
    PricingCalculatorBusinessCosts
  }

  import Ecto.Changeset
  import Ecto.Query

  use Ecto.Schema

  @total_hours_by_shoot %{
    boudoir: 27.94,
    event: 27.94,
    family: 18.97,
    headshot: 10.4,
    maternity: 18.97,
    mini: 10.4,
    other: 10.4,
    newborn: 27.94,
    portrait: 18.97,
    wedding: 66.57
  }

  defmodule LineItem do
    @moduledoc false
    use Ecto.Schema

    embedded_schema do
      field(:yearly_cost, Money.Ecto.Amount.Type)
      field(:yearly_cost_base, Money.Ecto.Amount.Type)
      field(:title, :string)
      field(:description, :string)
    end
  end

  defmodule BusinessCost do
    @moduledoc false
    use Ecto.Schema

    embedded_schema do
      field(:category, :string)
      field(:active, :boolean)
      field(:description, :string)
      embeds_many(:line_items, LineItem)
    end
  end

  defmodule PricingSuggestion do
    @moduledoc false
    use Ecto.Schema

    embedded_schema do
      field(:job_type, :string)
      field(:max_session_per_year, :integer)
      field(:base_price, Money.Ecto.Amount.Type)
    end
  end

  schema "pricing_calculations" do
    belongs_to(:organization, Organization)
    field(:average_time_per_week, :integer)
    field(:desired_salary, Money.Ecto.Amount.Type)
    field(:tax_bracket, :integer)
    field(:after_income_tax, Money.Ecto.Amount.Type)
    field(:self_employment_tax_percentage, :decimal)
    field(:take_home, Money.Ecto.Amount.Type)
    field(:job_types, {:array, :string})
    embeds_many(:business_costs, BusinessCost)
    embeds_many(:pricing_suggestions, PricingSuggestion)

    timestamps(type: :utc_datetime)
  end

  def changeset(%Picsello.PricingCalculations{} = pricing_calculations, attrs) do
    pricing_calculations
    |> cast(attrs, [
      :organization_id,
      :job_types,
      :after_income_tax,
      :average_time_per_week,
      :desired_salary,
      :self_employment_tax_percentage,
      :tax_bracket,
      :take_home
    ])
    |> validate_required([:job_types, :average_time_per_week])
    |> validate_number(:average_time_per_week,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 168,
      message: "Must be between 1 and 168 hours"
    )
    |> Picsello.Package.validate_money(:desired_salary,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647,
      message: "Salary cannot be that high"
    )
    |> cast_embed(:business_costs, with: &business_cost_changeset(&1, &2))
    |> cast_embed(:pricing_suggestions, with: &pricing_suggestions_changeset(&1, &2))
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

  defp pricing_suggestions_changeset(pricing_suggestion, attrs) do
    pricing_suggestion
    |> cast(attrs, [:max_session_per_year, :job_type, :base_price])
  end

  def find_income_tax_bracket?(
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

  def find_income_tax_bracket?(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          income_max: %Money{amount: _income_max},
          income_min: %Money{amount: _income_min}
        } = income_bracket,
        "" <> desired_salary_text
      ) do
    {:ok, value} = Money.parse(desired_salary_text)

    find_income_tax_bracket?(income_bracket, value)
  end

  def get_income_bracket(value) do
    %{income_brackets: income_brackets} = tax_schedule()

    income_brackets
    |> Enum.find(fn bracket -> find_income_tax_bracket?(bracket, scrub_money_input(value)) end)
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
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{},
        nil
      ) do
    Money.new(0)
  end

  def calculate_after_tax_income(
        %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
          fixed_cost_start: _fixed_cost_start,
          fixed_cost: _fixed_cost,
          percentage: _percentage
        } = income_bracket,
        "" <> desired_salary_text
      ) do
    calculate_after_tax_income(income_bracket, scrub_money_input(desired_salary_text))
  end

  def calculate_tax_amount(desired_salary, take_home) do
    scrub_money_input(desired_salary)
    |> Money.subtract(scrub_money_input(take_home))
  end

  def calculate_take_home_income(percentage, after_tax_income),
    do:
      after_tax_income
      |> Money.subtract(Money.multiply(after_tax_income, Decimal.div(percentage, 100)))

  def calculate_monthly(%Money{amount: amount}), do: Money.new(div(amount, 12))

  def calculate_monthly(amount) do
    scrub_money_input(amount)
    |> Money.divide(12)
    |> List.first()
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
      |> Enum.map(&busines_cost_map(&1))

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

  defp busines_cost_map(
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
        |> Enum.map(&line_items_map(&1)),
      active: active,
      description: description
    }
  end

  defp line_items_map(line_item) do
    item = struct(LineItem, Map.from_struct(line_item))
    {:ok, value} = item |> Map.fetch(:yearly_cost)

    item |> Map.put(:yearly_cost_base, value)
  end

  def calculate_revenue(
        desired_salary,
        costs
      ) do
    scrub_money_input(desired_salary)
    |> Money.add(costs)
  end

  def calculate_all_costs(business_costs) do
    business_costs
    |> Enum.filter(& &1.active)
    |> Enum.map(fn %{line_items: line_items} ->
      line_items |> calculate_costs_by_category()
    end)
    |> Enum.reduce(Money.new(0), fn item, acc ->
      Money.add(acc, item)
    end)
  end

  def calculate_costs_by_category(line_items) do
    line_items
    |> Enum.reduce(Money.new(0), fn item, acc ->
      Money.add(acc, item.yearly_cost)
    end)
  end

  def calculate_costs_by_category(_line_items, %{"line_items" => line_items} = _params) do
    line_items
    |> Enum.map(fn {_k, %{"yearly_cost" => yearly_cost}} ->
      %{yearly_cost: scrub_money_input(yearly_cost)}
    end)
    |> calculate_costs_by_category()
  end

  def calculate_costs_by_category(line_items, %{} = _params),
    do: calculate_costs_by_category(line_items)

  def calculate_pricing_by_job_types(%{
        job_types: job_types,
        average_time_per_week: average_time_per_week,
        desired_salary: desired_salary
      }) do
    job_types
    |> Enum.map(fn job_type ->
      shoots_per_year =
        calculate_shoots_per_year(scrub_time_per_week(average_time_per_week), job_type)

      %{
        job_type: job_type,
        base_price: calculate_shoot_base_price(desired_salary, shoots_per_year),
        max_session_per_year: shoots_per_year |> Decimal.round(0)
      }
    end)
  end

  defp calculate_shoots_per_year(average_time_per_week, job_type) do
    (calculate_hours_per_year(average_time_per_week) / get_shoot_hours_by_job_type(job_type))
    |> Decimal.from_float()
  end

  defp calculate_hours_per_year(average_time_per_week),
    do: average_time_per_week * 49

  defp get_shoot_hours_by_job_type(job_type),
    do: Map.fetch!(@total_hours_by_shoot, String.to_atom(job_type))

  defp calculate_shoot_base_price(desired_salary, shoots_per_year) do
    scrub_money_input(desired_salary)
    |> Money.to_decimal()
    |> Decimal.div(shoots_per_year)
    |> Money.parse!()
  end

  defp scrub_time_per_week(input) do
    case input do
      0 ->
        1

      "0" ->
        1

      "" ->
        1

      _ ->
        case Kernel.is_integer(input) do
          true -> input
          false -> String.to_integer(input)
        end
    end
  end

  defp scrub_money_input(input) do
    case input do
      %Money{} -> input
      "$" -> Money.new(0)
      "" -> Money.new(0)
      nil -> Money.new(0)
      _ -> Money.parse!(input)
    end
  end
end
