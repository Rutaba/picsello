defmodule Picsello.PricingCalculations do
  alias Picsello.{Repo, Organization}

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

    field(:desired_salary, :integer)
    field(:tax_bracket, :integer)
    field(:after_income_tax, :integer)
    field(:self_employment_tax, :integer)
    field(:take_home, :integer)
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
      :desired_salary
    ])
    |> IO.inspect()
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
      |> Enum.map(&{&1, &1})
end
