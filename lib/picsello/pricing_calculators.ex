defmodule Picsello.PricingCalculators do
  alias Picsello.{Repo, Accounts.User}

  import Ecto.Changeset
  import Picsello.Accounts.User, only: [put_new_attr: 3, update_attr_in: 3]
  import Ecto.Query

  defmodule PricingCalculator do
    use Ecto.Schema

    @days_of_the_week [
      monday: "Monday",
      tuesday: "Tuesday",
      wednesday: "Wednesday",
      thursday: "Thursday",
      friday: "Friday",
      saturday: "Saturday",
      sunday: "Sunday"
    ]

    embedded_schema do
      field(:changed_at, :utc_datetime)
      field(:average_time_per_week, :integer)
      field(:average_days_per_week, {:array, Ecto.Enum}, values: Keyword.keys(@days_of_the_week))
      field(:desired_salary, :integer)
      field(:tax_bracket, :integer)
      field(:after_income_tax, :integer)
      field(:self_employment_tax, :integer)
      field(:take_home, :integer)
    end

    def changeset(%__MODULE__{} = pricing_calculator, attrs) do
      pricing_calculator
      |> cast(attrs, [
        :changed_at,
        :average_time_per_week,
        :average_days_per_week,
        :desired_salary,
        :tax_bracket,
        :after_income_tax,
        :self_employment_tax,
        :take_home
      ])
      |> validate_required([
        :changed_at,
        :average_time_per_week,
        :average_days_per_week,
        :desired_salary,
        :tax_bracket,
        :after_income_tax,
        :self_employment_tax,
        :take_home
      ])
    end
  end

  def changeset(%User{} = user, attrs, opts \\ []) do
    step = Keyword.get(opts, :step, 5)

    user
    |> cast(%{pricing_calculator: []}, [])
    |> IO.inspect()
  end

  def state_options(),
    do:
      from(adjustment in Picsello.Packages.CostOfLivingAdjustment,
        select: adjustment.state,
        order_by: adjustment.state
      )
      |> Repo.all()
      |> Enum.map(&{&1, &1})
end
