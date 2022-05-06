defmodule Picsello.Cart.OrderTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.Cart.Order

  describe "priced_lines_by_product" do
    test "newest group first, newest change first" do
      order =
        insert(:order,
          products:
            insert_list(2, :product)
            |> Enum.flat_map(
              &build_list(2, :cart_product,
                round_up_to_nearest: 100,
                shipping_base_charge: ~M[300]USD,
                unit_markup: ~M[100]USD,
                unit_price: ~M[0]USD,
                whcc_product: &1
              )
            )
            |> Enum.with_index()
            |> Enum.map(fn {product, index} -> %{product | created_at: index} end)
        )

      assert [
               {%Picsello.Product{},
                [%{line_item: %{created_at: 3}}, %{line_item: %{created_at: 2}}]},
               {%Picsello.Product{},
                [%{line_item: %{created_at: 1}}, %{line_item: %{created_at: 0}}]}
             ] = Order.priced_lines_by_product(order)
    end
  end

  describe "priced_lines" do
    test "with 1 line for 1 product, quantity 1 - no discount" do
      order =
        insert(:order,
          products: [
            build(:cart_product,
              round_up_to_nearest: 100,
              shipping_base_charge: ~M[300]USD,
              shipping_upcharge: Decimal.new(0),
              unit_markup: ~M[100]USD,
              unit_price: ~M[0]USD,
              whcc_product: insert(:product)
            )
          ]
        )

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD}
             ] = Order.priced_lines(order)
    end

    test "with 1 lines for 1 product, quantity 2 - discount" do
      order =
        insert(:order,
          products: [
            build(:cart_product,
              quantity: 2,
              round_up_to_nearest: 1,
              shipping_upcharge: Decimal.new(0),
              shipping_base_charge: ~M[300]USD,
              unit_markup: ~M[100]USD,
              unit_price: ~M[0]USD,
              whcc_product: insert(:product)
            )
          ]
        )

      assert [
               %{price: ~M[500]USD, price_without_discount: ~M[800]USD}
             ] = Order.priced_lines(order)
    end

    test "with 2 lines for 1 product, quantity 1 - discount on second" do
      order =
        insert(:order,
          products:
            build_list(2, :cart_product,
              round_up_to_nearest: 100,
              shipping_base_charge: ~M[300]USD,
              unit_markup: ~M[100]USD,
              unit_price: ~M[0]USD,
              whcc_product: insert(:product)
            )
        )

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD}
             ] = Order.priced_lines(order)
    end

    test "with 2 lines for 2 products, quantity 1 - discount on second of each" do
      order =
        insert(:order,
          products:
            insert_list(2, :product)
            |> Enum.flat_map(
              &build_list(2, :cart_product,
                round_up_to_nearest: 100,
                shipping_base_charge: ~M[300]USD,
                unit_markup: ~M[100]USD,
                unit_price: ~M[0]USD,
                whcc_product: &1
              )
            )
        )

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD}
             ] = Order.priced_lines(order)
    end
  end
end
