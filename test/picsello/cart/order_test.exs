defmodule Picsello.Cart.OrderTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.{Cart.Order, Repo}

  describe "priced_lines_by_product" do
    test "newest group first, newest change first" do
      %{products: products} =
        order =
        insert(:order,
          products:
            insert_list(2, :product)
            |> Enum.flat_map(&build_list(2, :cart_product, whcc_product: &1))
            |> Enum.with_index()
            |> Enum.map(fn {product, index} ->
              %{product | inserted_at: DateTime.utc_now() |> DateTime.add(index)}
            end)
        )

      assert [{_, product_1_items}, {_, product_2_items}] = Order.priced_lines_by_product(order)

      assert [Enum.at(products, 3), Enum.at(products, 2)] ==
               Enum.map(product_1_items, & &1.line_item)

      assert [Enum.at(products, 1), Enum.at(products, 0)] ==
               Enum.map(product_2_items, & &1.line_item)
    end
  end

  describe "priced_lines" do
    setup do
      [order: :order |> insert() |> Repo.preload(:products)]
    end

    test "with 1 line for 1 product, quantity 1 - no discount", %{order: order} do
      order =
        order
        |> Order.update_changeset(
          build(:cart_product,
            round_up_to_nearest: 100,
            shipping_base_charge: ~M[300]USD,
            shipping_upcharge: Decimal.new(0),
            unit_markup: ~M[100]USD,
            unit_price: ~M[0]USD,
            whcc_product: insert(:product)
          )
        )
        |> Repo.update!()

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD}
             ] = Order.priced_lines(order)
    end

    test "with 1 lines for 1 product, quantity 2 - discount", %{order: order} do
      order =
        order
        |> Order.update_changeset(
          build(:cart_product,
            quantity: 2,
            round_up_to_nearest: 1,
            shipping_upcharge: Decimal.new(0),
            shipping_base_charge: ~M[300]USD,
            unit_markup: ~M[100]USD,
            unit_price: ~M[0]USD,
            whcc_product: insert(:product)
          )
        )
        |> Repo.update!()

      assert [
               %{price: ~M[500]USD, price_without_discount: ~M[800]USD}
             ] = Order.priced_lines(order)
    end

    test "with 2 lines for 1 product, quantity 1 - discount on second", %{order: order} do
      order =
        for product <-
              build_list(2, :cart_product,
                round_up_to_nearest: 100,
                shipping_base_charge: ~M[300]USD,
                unit_markup: ~M[100]USD,
                unit_price: ~M[0]USD,
                whcc_product: insert(:product)
              ),
            reduce: order do
          order ->
            order |> Order.update_changeset(product) |> Repo.update!()
        end

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD}
             ] = Order.priced_lines(order)
    end

    test "with 2 lines for 2 products, quantity 1 - discount on second of each", %{order: order} do
      order =
        for product <-
              insert_list(2, :product)
              |> Enum.flat_map(
                &build_list(2, :cart_product,
                  round_up_to_nearest: 100,
                  shipping_base_charge: ~M[300]USD,
                  unit_markup: ~M[100]USD,
                  unit_price: ~M[0]USD,
                  whcc_product: &1
                )
              ),
            reduce: order do
          order ->
            order
            |> Order.update_changeset(product)
            |> Repo.update!()
        end

      order
      |> Ecto.assoc(:products)
      |> Repo.all()
      |> Enum.map(&Map.take(&1, [:id, :whcc_product_id, :volume_discount, :price]))

      assert [
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[400]USD, price_without_discount: ~M[400]USD},
               %{price: ~M[100]USD, price_without_discount: ~M[400]USD}
             ] =
               order
               |> Order.priced_lines()
               |> Enum.map(&Map.take(&1, [:price, :price_without_discount]))
    end
  end
end
