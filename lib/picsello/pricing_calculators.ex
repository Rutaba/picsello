defmodule Picsello.PricingCalculators do
  alias Picsello.{Repo, Accounts.User}

  import Ecto.Changeset
  import Ecto.Query

  defmodule PricingCalculator do
    use Ecto.Schema

    defmodule CalculationState do
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
    end

    @primary_key false
    embedded_schema do
      embeds_many(:calculations, CalculationState)
    end

    # def changeset(%__MODULE__{} = pricing_calculator, attrs) do
    #   pricing_calculator
    #   |> cast(attrs, [
    #     :calculations
    #   ])
    #   |> validate_required([
    #     :calculations
    #   ])
    # end
  end

  def changeset(%User{} = user, attrs, opts \\ []) do
    step = Keyword.get(opts, :step, 5)

    new_calc_state = %PricingCalculator.CalculationState{
      changed_at: DateTime.utc_now(),
      average_time_per_week: 0
    }

    user
    |> cast(%{pricing_calculator: %{}}, [])
    |> cast_embed(:pricing_calculator,
      with: fn %{calculations: calculations} = pricing_calculator, _ ->
        pricing_calculator
        |> IO.inspect()
        |> change()
        |> put_embed(:calculations, [new_calc_state | calculations])
        |> IO.inspect()
      end
    )
  end

  def day_options(),
    do: [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ]

  def cost_categories(),
    do: [
      %{
        title: "Equipment",
        base_cost: "$7,170",
        id: 0,
        description: "Lorem ipsum really short description goes here about the costs listed here"
      },
      %{
        title: "Software",
        base_cost: "$3,204",
        id: 1,
        description:
          "Lorem ipsum really short description goes here about the costs listed here 2"
      },
      %{
        title: "Office Supplies",
        base_cost: "$360",
        id: 2,
        description:
          "Lorem ipsum really short description goes here about the costs listed here 2"
      },
      %{
        title: "Marketing",
        base_cost: "$10,396",
        id: 3,
        description:
          "Lorem ipsum really short description goes here about the costs listed here 2"
      },
      %{
        title: "Operations",
        base_cost: "$5,112",
        id: 4,
        description:
          "Lorem ipsum really short description goes here about the costs listed here 2"
      },
      %{
        title: "Training",
        base_cost: "$2,004",
        id: 5,
        description:
          "Lorem ipsum really short description goes here about the costs listed here 2"
      }
    ]

  def state_options(),
    do:
      from(adjustment in Picsello.Packages.CostOfLivingAdjustment,
        select: adjustment.state,
        order_by: adjustment.state
      )
      |> Repo.all()
      |> IO.inspect()
      |> Enum.map(&{&1, &1})
end
