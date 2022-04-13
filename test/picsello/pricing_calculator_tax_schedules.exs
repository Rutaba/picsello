defmodule Picsello.PricingCalculatorBusinessCostsTest do
  use Picsello.DataCase, async: true
  import Money.Sigils

  alias Picsello.{
    Repo,
    PricingCalculatorTaxSchedules
  }

  def tax_schedule_base,
    do: %{
      year: DateTime.utc_now() |> Map.fetch!(:year),
      active: false,
      income_brackets: [
        %{
          income_min: ~M[0],
          income_max: ~M[100],
          percentage: 1,
          fixed_cost: ~M[500]
        }
      ]
    }

  describe "create and modify changeset" do
    test "add pricing calculator tax_schedule with default income bracket" do
      assert %{
               year: 2022,
               active: false,
               income_brackets: [%{income_min: %Money{amount: 000, currency: :USD}}]
             } =
               PricingCalculatorTaxSchedules.changeset(
                 %PricingCalculatorTaxSchedules{},
                 tax_schedule_base()
               )
               |> Repo.insert!()
    end

    test "update pricing calculator tax_schedule" do
      base_tax_schedule =
        PricingCalculatorTaxSchedules.changeset(
          %PricingCalculatorTaxSchedules{},
          tax_schedule_base()
        )
        |> Repo.insert!()

      PricingCalculatorTaxSchedules.changeset(
        base_tax_schedule,
        %{
          year: 2023,
          active: true,
          income_brackets: [
            %{
              fixed_cost: %Money{amount: 30000, currency: :USD},
              fixed_cost_start: nil,
              income_max: %Money{amount: 40000, currency: :USD},
              income_min: %Money{amount: 0, currency: :USD},
              percentage: 10
            }
            | base_tax_schedule.income_brackets |> Enum.map(&Map.from_struct(&1))
          ]
        }
      )
      |> Repo.update!()
    end

    test "add pricing calculator income_bracket" do
      base_tax_schedule =
        PricingCalculatorTaxSchedules.changeset(
          %PricingCalculatorTaxSchedules{},
          tax_schedule_base()
        )
        |> Repo.insert!()

      assert %{
               year: 2022,
               active: false,
               income_brackets: [
                 %{
                   income_max: %Money{amount: 600_000, currency: :USD},
                   fixed_cost: %Money{amount: 50000, currency: :USD}
                 },
                 %{fixed_cost: %Money{amount: 500, currency: :USD}}
               ]
             } =
               PricingCalculatorTaxSchedules.add_income_bracket_changeset(
                 base_tax_schedule,
                 %Picsello.PricingCalculatorTaxSchedules.IncomeBracket{
                   fixed_cost: ~M[50000],
                   income_max: ~M[600000],
                   income_min: ~M[1000],
                   percentage: 37
                 }
               )
               |> Repo.update!()
    end
  end
end
