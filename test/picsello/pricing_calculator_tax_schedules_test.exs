defmodule Picsello.PricingCalculatorTaxSchedulesTest do
  @moduledoc false
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
               income_brackets: [%{income_min: ~M[000]}]
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
              fixed_cost: ~M[30000],
              fixed_cost_start: nil,
              income_max: ~M[40000],
              income_min: ~M[000],
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
                   income_max: ~M[600000],
                   fixed_cost: ~M[50000]
                 },
                 %{fixed_cost: ~M[500]}
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
