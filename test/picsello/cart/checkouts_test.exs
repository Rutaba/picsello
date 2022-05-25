defmodule Picsello.Cart.CheckoutsTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Galleries, Cart.Order, WHCC.Editor.Export, MockWHCCClient, Cart.Checkouts}

  setup do
    Mox.verify_on_exit!()
  end

  describe "create_whcc_order" do
    setup do
      cart_products =
        for {product, index} <-
              Enum.with_index([insert(:product) | List.duplicate(insert(:product), 2)]) do
          build(:cart_product,
            whcc_product: product,
            inserted_at: DateTime.utc_now() |> DateTime.add(index)
          )
        end

      gallery = insert(:gallery)
      order = insert(:order, products: cart_products, gallery: gallery)

      [
        cart_products: cart_products,
        order:
          order
          |> Repo.preload([:package, :digitals, products: :whcc_product], force: true),
        account_id: Galleries.account_id(gallery),
        order_number: Order.number(order)
      ]
    end

    test "exports editors, providing shipping information", %{
      order: order,
      account_id: account_id,
      order_number: order_number,
      cart_products: cart_products
    } do
      MockWHCCClient
      |> Mox.expect(:editors_export, fn ^account_id, editors, opts ->
        assert cart_products |> Enum.map(& &1.editor_id) |> MapSet.new() ==
                 editors |> Enum.map(& &1.id) |> MapSet.new()

        assert to_string(order_number) == Keyword.get(opts, :entry_id)

        %Export{}
      end)
      |> Mox.expect(:create_order, fn ^account_id, _export ->
        build(:whcc_order_created)
      end)

      Checkouts.create_whcc_order(order)
    end
  end
end
