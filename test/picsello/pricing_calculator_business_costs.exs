defmodule Picsello.PricingCalculatorBusinessCostsTest do
  @moduledoc false
  use Picsello.DataCase, async: true
  import Money.Sigils

  alias Picsello.{
    Repo,
    PricingCalculatorBusinessCosts
  }

  def add_business_cost_category,
    do: %{
      category: "Equipment",
      active: true,
      line_items: [
        %{
          title: "Camera",
          description: "The item that runs your business",
          yearly_cost: ~M[10000]
        }
      ]
    }

  describe "create and modify changeset" do
    test "insert pricing calculator business cost" do
      assert %{active: true, category: "Equipment", line_items: [%{title: "Camera"}]} =
               PricingCalculatorBusinessCosts.changeset(
                 %PricingCalculatorBusinessCosts{},
                 add_business_cost_category()
               )
               |> Repo.insert!()
    end

    test "update pricing calculator business cost" do
      base_business_cost =
        PricingCalculatorBusinessCosts.changeset(
          %PricingCalculatorBusinessCosts{},
          add_business_cost_category()
        )
        |> Repo.insert!()

      assert %{
               active: false,
               category: "Equipment",
               line_items: [
                 %{title: "Light", yearly_cost: ~M[50000]},
                 %{title: "Camera"}
               ]
             } =
               PricingCalculatorBusinessCosts.changeset(
                 base_business_cost,
                 %{
                   year: 2023,
                   active: false,
                   line_items: [
                     %{
                       title: "Light",
                       description: "Light your subject",
                       yearly_cost: ~M[50000]
                     }
                     | base_business_cost.line_items |> Enum.map(&Map.from_struct(&1))
                   ]
                 }
               )
               |> Repo.update!()
    end

    test "add pricing calculator line_item" do
      base_business_cost =
        PricingCalculatorBusinessCosts.changeset(
          %PricingCalculatorBusinessCosts{},
          add_business_cost_category()
        )
        |> Repo.insert!()

      assert %{
               active: true,
               line_items: [
                 %{title: "Light", yearly_cost: %Money{amount: ~M[50000], currency: :USD}},
                 %{title: "Camera"}
               ]
             } =
               PricingCalculatorBusinessCosts.add_business_cost_changeset(
                 base_business_cost,
                 %Picsello.PricingCalculatorBusinessCosts.BusinessCost{
                   title: "Light",
                   description: "Light your subject",
                   yearly_cost: ~M[50000]
                 }
               )
               |> Repo.update!()
    end
  end
end
