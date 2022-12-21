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

      assert [{_, product_1_items}, {_, product_2_items}] = Order.lines_by_product(order)

      assert [Enum.at(products, 3), Enum.at(products, 2)] == product_1_items

      assert [Enum.at(products, 1), Enum.at(products, 0)] == product_2_items
    end
  end

  describe "update_changeset" do
    setup do
      [order: :order |> insert() |> Repo.preload(:products)]
    end

    def update_changeset(order, product) do
      order
      |> Repo.preload([products: :whcc_product], force: true)
      |> Order.update_changeset(product)
      |> Repo.update!()
    end

    test "with 1 line for 1 product, quantity 1 - no discount", %{order: order} do
      order =
        order
        |> update_changeset(
          build(:cart_product,
            round_up_to_nearest: 100,
            shipping_base_charge: ~M[300]USD,
            shipping_upcharge: Decimal.new(0),
            unit_markup: ~M[100]USD,
            unit_price: ~M[0]USD
          )
        )

      assert [
               %{price: ~M[600]USD, volume_discount: ~M[0]USD}
             ] = order.products
    end

    test "with 1 lines for 1 product, quantity 2 - discount", %{order: order} do
      order =
        order
        |> update_changeset(
          build(:cart_product,
            quantity: 2,
            round_up_to_nearest: 1,
            shipping_upcharge: Decimal.new(0),
            shipping_base_charge: ~M[300]USD,
            unit_markup: ~M[100]USD,
            unit_price: ~M[0]USD
          )
        )

      assert [
               %{price: ~M[1200]USD, volume_discount: ~M[600]USD}
             ] = order.products
    end

    test "with 2 lines for 1 product, quantity 1 - discount on second", %{order: order} do
      whcc_product = insert(:product)

      order =
        for product <-
              build_list(2, :cart_product,
                round_up_to_nearest: 100,
                shipping_base_charge: ~M[300]USD,
                unit_markup: ~M[100]USD,
                unit_price: ~M[0]USD,
                whcc_product: whcc_product
              ),
            reduce: order do
          order -> update_changeset(order, product)
        end

      assert [
               %{volume_discount: ~M[00]USD, price: ~M[600]USD},
               %{volume_discount: ~M[600]USD, price: ~M[600]USD}
             ] = order.products |> Enum.map(&Map.take(&1, [:price, :volume_discount]))
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
                  whcc_product: &1,
                  volume_discount: nil
                )
              ),
            reduce: order do
          order ->
            update_changeset(order, product)
        end
        |> Repo.preload([:products], force: true)

      assert [
               %{price: ~M[600]USD, volume_discount: ~M[0]USD},
               %{price: ~M[600]USD, volume_discount: ~M[600]USD},
               %{price: ~M[600]USD, volume_discount: ~M[0]USD},
               %{price: ~M[600]USD, volume_discount: ~M[600]USD}
             ] = order.products |> Enum.map(&Map.take(&1, [:price, :volume_discount]))
    end
  end
end
