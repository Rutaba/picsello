defmodule Picsello.PricingCalculationsTest do
  use Picsello.DataCase, async: true
  import Money.Sigils

  alias Picsello.{
    Repo,
    PricingCalculatorTaxSchedules,
    PricingCalculatorBusinessCosts,
    PricingCalculations
  }

  def tax_schedule_base,
    do: %{
      year: DateTime.utc_now() |> Map.fetch!(:year),
      active: true,
      self_employment_percentage: 15.3,
      income_brackets: [
        %{
          income_min: ~M[0],
          income_max: ~M[100],
          fixed_cost_start: ~M[0],
          percentage: 1,
          fixed_cost: ~M[00]
        },
        %{
          income_min: ~M[100],
          income_max: ~M[0],
          fixed_cost_start: ~M[100],
          percentage: 1,
          fixed_cost: ~M[500]
        }
      ]
    }

  def add_business_cost_category,
    do: %{
      id: "1234",
      category: "Equipment",
      active: true,
      line_items: [
        %{
          title: "Camera",
          description: "The item that runs your business",
          yearly_cost: ~M[10000],
          yearly_cost_base: ~M[10000]
        },
        %{
          title: "Light",
          description: "The item that lights your subject",
          yearly_cost: ~M[50000],
          yearly_cost_base: ~M[50000]
        }
      ]
    }

  def generate_base_pricing_calculation(user, zipcode \\ ""),
    do: %{
      organization_id: user.organization_id,
      job_types: user.organization.profile.job_types,
      state: user.onboarding.state,
      min_years_experience: user.onboarding.photographer_years,
      schedule: Atom.to_string(user.onboarding.schedule),
      take_home: ~M[000],
      business_costs: PricingCalculations.cost_categories(),
      self_employment_tax_percentage:
        PricingCalculations.tax_schedule().self_employment_percentage,
      desired_salary: ~M[150000],
      zipcode: zipcode
    }

  setup do
    insert(:cost_of_living_adjustment)

    organization =
      insert(:organization,
        profile: %{
          name: "Mary Jane Photography",
          slug: "mary-jane-photos",
          job_types: ~w(portrait event),
          website: "photos.example.com"
        }
      )

    PricingCalculatorTaxSchedules.changeset(
      %PricingCalculatorTaxSchedules{},
      tax_schedule_base()
    )
    |> Repo.insert!()

    PricingCalculatorBusinessCosts.changeset(
      %PricingCalculatorBusinessCosts{},
      add_business_cost_category()
    )
    |> Repo.insert!()

    user =
      insert(:user,
        onboarding: %{schedule: :full_time, state: "OK", photographer_years: 3},
        organization: organization
      )

    pricing_calculation_changeset =
      PricingCalculations.changeset(
        struct(PricingCalculations, generate_base_pricing_calculation(user, "98661")),
        %{}
      )

    %{
      user: user,
      pricing_calculation_changeset: pricing_calculation_changeset
    }
  end

  describe "create and modify changeset" do
    test "creates default changeset with existing data but no zipcode", %{
      user: user
    } do
      {:error, changeset} =
        PricingCalculations.changeset(
          struct(PricingCalculations, generate_base_pricing_calculation(user)),
          %{}
        )
        |> Repo.insert()

      assert %{
               zipcode: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "creates default changeset with existing data", %{
      pricing_calculation_changeset: pricing_calculation_changeset
    } do
      assert %Ecto.Changeset{errors: []} = pricing_calculation_changeset
    end

    test "update changeset with business_costs", %{
      pricing_calculation_changeset: pricing_calculation_changeset
    } do
      pricing_calculation =
        pricing_calculation_changeset
        |> Repo.insert_or_update!()

      business_cost =
        pricing_calculation.business_costs
        |> List.last()
        |> Map.from_struct()

      business_costs_to_update =
        business_cost
        |> Map.put(
          :line_items,
          business_cost.line_items
          |> Enum.map(&Map.from_struct(&1))
        )

      assert %Ecto.Changeset{
               errors: []
             } =
               PricingCalculations.changeset(
                 pricing_calculation,
                 %{
                   business_costs: [
                     %{
                       category: "Software",
                       active: true,
                       line_items: [
                         %{
                           title: "Adobe Lightroom",
                           description: "The item that runs your business",
                           yearly_cost: ~M[12000],
                           yearly_cost_base: ~M[12000]
                         }
                       ]
                     }
                     | [business_costs_to_update]
                   ]
                 }
               )
    end

    test "update changeset with pricing_suggestions", %{
      pricing_calculation_changeset: pricing_calculation_changeset
    } do
      pricing_calculation =
        pricing_calculation_changeset
        |> Repo.insert_or_update!()

      assert %Ecto.Changeset{
               errors: []
             } =
               PricingCalculations.changeset(
                 pricing_calculation,
                 %{
                   pricing_suggestions: [
                     %{
                       max_session_per_year: 24,
                       job_type: "portrait",
                       base_price: ~M[12000],
                       test: "test"
                     }
                   ]
                 }
               )
    end
  end

  describe "calculation cases" do
    test "compare_income_bracket with %Money{}" do
      income_brackets = PricingCalculations.tax_schedule().income_brackets

      assert true ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket(%Money{amount: 5000, currency: :USD})

      assert true ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket(%Money{
                 amount: 500_000_000,
                 currency: :USD
               })

      assert false ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket(%Money{amount: 000, currency: :USD})

      assert true ==
               income_brackets
               |> List.first()
               |> PricingCalculations.compare_income_bracket(%Money{amount: 000, currency: :USD})

      assert false ==
               income_brackets
               |> List.first()
               |> PricingCalculations.compare_income_bracket(%Money{
                 amount: 500_000_000,
                 currency: :USD
               })
    end

    test "compare_income_bracket with raw text" do
      income_brackets = PricingCalculations.tax_schedule().income_brackets

      assert true ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket("5000")

      assert true ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket("500000000")

      assert false ==
               income_brackets
               |> List.last()
               |> PricingCalculations.compare_income_bracket("000")

      assert true ==
               income_brackets
               |> List.first()
               |> PricingCalculations.compare_income_bracket("000")

      assert false ==
               income_brackets
               |> List.first()
               |> PricingCalculations.compare_income_bracket("500000000")
    end

    test "get_income_bracket with multiple string values from form params" do
      assert %{income_max: %Money{amount: 100, currency: :USD}} =
               PricingCalculations.get_income_bracket("$")

      assert %{income_max: %Money{amount: 100, currency: :USD}} =
               PricingCalculations.get_income_bracket(nil)

      assert %{
               income_max: %Money{amount: 0, currency: :USD},
               income_min: %Money{amount: 100, currency: :USD}
             } = PricingCalculations.get_income_bracket(50000)
    end

    test "calculate_after_tax_income with %Money{}" do
      income_bracket = PricingCalculations.tax_schedule().income_brackets |> List.last()

      assert %Money{amount: 494_501, currency: :USD} =
               PricingCalculations.calculate_after_tax_income(income_bracket, %Money{
                 amount: 500_000,
                 currency: :USD
               })
    end

    test "calculate_after_tax_income with nil" do
      income_bracket = PricingCalculations.tax_schedule().income_brackets |> List.last()

      assert %Money{amount: 0, currency: :USD} =
               PricingCalculations.calculate_after_tax_income(income_bracket, nil)
    end

    test "calculate_after_tax_income with multiple string values from form params" do
      income_bracket = PricingCalculations.tax_schedule().income_brackets |> List.last()

      assert %Money{} = PricingCalculations.calculate_after_tax_income(income_bracket, "$")

      assert %Money{amount: 494_501, currency: :USD} =
               PricingCalculations.calculate_after_tax_income(income_bracket, "$5000.00")
    end

    test "calculate_take_home_income" do
      assert %Money{amount: 418_842, currency: :USD} =
               PricingCalculations.calculate_take_home_income(
                 PricingCalculations.tax_schedule().self_employment_percentage,
                 %Money{amount: 494_501, currency: :USD}
               )
    end

    test "calculate_monthly with %Money{}" do
      assert %Money{amount: 1_000_000, currency: :USD} =
               PricingCalculations.calculate_monthly(%Money{amount: 12_000_000, currency: :USD})
    end

    test "calculate_monthly with multiple string values from form params" do
      assert %Money{amount: 0, currency: :USD} = PricingCalculations.calculate_monthly("$")

      assert %Money{amount: 0, currency: :USD} = PricingCalculations.calculate_monthly(nil)

      assert %Money{amount: 1_000_000, currency: :USD} =
               PricingCalculations.calculate_monthly("$12,0000")
    end

    test "get cost categories" do
      assert %{
               category: "Equipment",
               active: true,
               line_items: [
                 %{title: "Camera", yearly_cost: %Money{amount: 600_000, currency: :USD}},
                 %{title: "Light", yearly_cost: %Money{amount: 50000, currency: :USD}}
               ]
             } =
               Picsello.PricingCalculatorBusinessCosts.changeset(
                 %Picsello.PricingCalculatorBusinessCosts{},
                 Picsello.Factory.business_cost_factory()
               )
               |> Repo.insert!()
    end

    test "get day options" do
      assert [
               "monday",
               "tuesday",
               "wednesday",
               "thursday",
               "friday",
               "saturday",
               "sunday"
             ] = PricingCalculations.day_options()
    end

    test "get tax schedules" do
      assert %{
               self_employment_percentage: %Decimal{},
               active: true,
               income_brackets: [
                 %{fixed_cost_start: %Money{amount: 0, currency: :USD}},
                 %{income_min: %Money{amount: 999_500, currency: :USD}, percentage: %Decimal{}}
               ]
             } =
               Picsello.PricingCalculatorTaxSchedules.changeset(
                 %Picsello.PricingCalculatorTaxSchedules{},
                 Picsello.Factory.tax_schedule_factory()
               )
               |> Picsello.Repo.insert!()
    end

    test "get state options" do
      assert [{"OK", "OK"}] = PricingCalculations.state_options()
    end

    test "calculate_all_costs", %{pricing_calculation_changeset: pricing_calculation_changeset} do
      pricing_calculation = pricing_calculation_changeset |> Repo.insert_or_update!()

      assert %Money{amount: 60000, currency: :USD} =
               PricingCalculations.calculate_all_costs(pricing_calculation.business_costs)
    end

    test "calculate_costs_by_category with line_times[%Money{}]" do
      assert %Money{amount: 60000, currency: :USD} =
               PricingCalculations.calculate_costs_by_category([
                 %{
                   description: "The item that runs your business",
                   id: "12345",
                   title: "Camera",
                   yearly_cost: %Money{amount: 10000, currency: :USD},
                   yearly_cost_base: %Money{amount: 10000, currency: :USD}
                 },
                 %{
                   description: "The item that lights your subject",
                   id: "6789",
                   title: "Light",
                   yearly_cost: %Money{amount: 50000, currency: :USD},
                   yearly_cost_base: %Money{amount: 50000, currency: :USD}
                 }
               ])
    end

    test "calculate_costs_by_category with line_times[with multiple string values from form params]" do
      assert %Money{amount: 100_000, currency: :USD} =
               PricingCalculations.calculate_costs_by_category(
                 nil,
                 %{
                   "line_items" => %{
                     "0" => %{
                       "id" => "12345",
                       "yearly_cost" => "$1000",
                       "yearly_cost_base" => "$1000"
                     },
                     "1" => %{
                       "id" => "45678",
                       "yearly_cost" => "$",
                       "yearly_cost_base" => "$"
                     }
                   }
                 }
               )
    end

    test "calculate_costs_by_category with line_times[%{}]" do
      assert %Money{amount: 60000, currency: :USD} =
               PricingCalculations.calculate_costs_by_category(
                 [
                   %{
                     description: "The item that runs your business",
                     id: "12345",
                     title: "Camera",
                     yearly_cost: %Money{amount: 10000, currency: :USD},
                     yearly_cost_base: %Money{amount: 10000, currency: :USD}
                   },
                   %{
                     description: "The item that lights your subject",
                     id: "6789",
                     title: "Light",
                     yearly_cost: %Money{amount: 50000, currency: :USD},
                     yearly_cost_base: %Money{amount: 50000, currency: :USD}
                   }
                 ],
                 %{}
               )
    end
  end
end
