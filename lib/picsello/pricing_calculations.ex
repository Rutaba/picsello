defmodule Picsello.PricingCalculations do
  @moduledoc false
  alias Picsello.{
    Repo,
    Organization,
    PricingCalculatorTaxSchedules,
    PricingCalculatorBusinessCosts,
    Packages.BasePrice,
    Packages.CostOfLivingAdjustment
  }

  import Ecto.Changeset
  import Ecto.Query

  use Ecto.Schema

  import Picsello.Repo.CustomMacros

  @zipcode_regex ~r/^\d{5}([-]|\s*)?(\d{4})?$/

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
    embeds_many(:pricing_suggestions, PricingSuggestion)

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
      :after_income_tax,
      :average_days_per_week,
      :average_time_per_week,
      :desired_salary,
      :self_employment_tax_percentage,
      :tax_bracket,
      :take_home
    ])
    |> validate_required([:job_types, :state, :min_years_experience])
    |> maybe_validate_zipcode()
    |> validate_number(:average_time_per_week,
      less_than_or_equal_to: 168,
      message: "There are not that many hours in a week"
    )
    |> Picsello.Package.validate_money(:desired_salary,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2_147_483_647,
      message: "Salary cannot be that high"
    )
    |> cast_embed(:business_costs, with: &business_cost_changeset(&1, &2))
    |> cast_embed(:pricing_suggestions, with: &pricing_suggestions_changeset(&1, &2))
  end

  defp maybe_validate_zipcode(changeset) do
    state = get_field(changeset, :state)

    if Picsello.Onboardings.non_us_state?(state) do
      changeset
    else
      changeset
      |> validate_required([:zipcode])
      |> validate_format(:zipcode, @zipcode_regex, message: "is invalid")
    end
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

    scrub_input =
      case value do
        "$" -> Money.new(0)
        nil -> Money.new(0)
        _ -> value
      end

    income_brackets
    |> Enum.find(fn bracket -> find_income_tax_bracket?(bracket, scrub_input) end)
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
    scrub_input =
      case desired_salary_text do
        "$" -> "$0.00"
        _ -> desired_salary_text
      end

    {:ok, desired_salary} = Money.parse(scrub_input)

    calculate_after_tax_income(income_bracket, desired_salary)
  end

  def calculate_take_home_income(percentage, after_tax_income),
    do:
      after_tax_income
      |> Money.subtract(Money.multiply(after_tax_income, Decimal.div(percentage, 100)))

  def calculate_monthly(%Money{amount: amount}), do: Money.new(div(amount, 12))

  def calculate_monthly(amount) do
    scrub_input =
      case amount do
        "$" -> "$0.00"
        nil -> "$0.00"
        _ -> amount
      end

    Money.parse!(scrub_input)
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
      ),
      do: Money.add(desired_salary, costs)

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
      scrub_input =
        case yearly_cost do
          "$" -> "$0.00"
          "" -> "$0.00"
          _ -> yearly_cost
        end

      %{yearly_cost: Money.parse!(scrub_input, :USD)}
    end)
    |> calculate_costs_by_category()
  end

  def calculate_costs_by_category(line_items, %{} = _params),
    do: calculate_costs_by_category(line_items)

  def calculate_pricing_by_job_types(%{
        min_years_experience: min_years_experience,
        state: state,
        schedule: schedule,
        job_types: job_types
      }) do
    full_time = schedule == :full_time
    nearest = 500

    min_years_query =
      from(base in BasePrice,
        select: max(base.min_years_experience),
        where: base.min_years_experience <= ^min_years_experience
      )

    from(base in BasePrice,
      where:
        base.full_time == ^full_time and base.job_type in ^job_types and
          base.min_years_experience in subquery(min_years_query),
      join: adjustment in CostOfLivingAdjustment,
      on: adjustment.state == ^state,
      group_by: base.job_type,
      select: %{
        record_count: count(base.job_type),
        job_type: base.job_type,
        base_price:
          cast_money(
            avg(
              type(
                nearest(adjustment.multiplier * base.base_price, ^nearest),
                base.base_price
              )
            )
          ),
        shoot_count: type(avg(base.shoot_count), :integer),
        max_session_per_year: type(avg(base.max_session_per_year), :integer),
        max_session_per_month: type(avg(base.max_session_per_year / 12), :integer)
      }
    )
    |> Repo.all()
  end

  def calculate_min_sessions_a_year(%Money{amount: gross_revenue}, %Money{amount: base_price}),
    do: div(gross_revenue, base_price)
end
