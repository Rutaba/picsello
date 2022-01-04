defmodule Picsello.Cart.CartProductTest do
  use Picsello.DataCase, async: true

  import Picsello.Factory

  alias Picsello.Cart

  describe "cart porduct updates" do
    test "find and save processing status" do
      gallery = insert(:gallery)
      cart_product = confirmed_product()
      order = Cart.place_product(cart_product, gallery.id)

      editor_id = cart_product.editor_details.editor_id

      found_order = Cart.order_with_editor(editor_id)

      assert found_order.id == order.id
      assert found_order.products |> Enum.at(0) |> Map.get(:whcc_processing) == nil

      Cart.store_cart_product_processing(processing_status(editor_id))

      updated_order = Cart.order_with_editor(editor_id)

      assert updated_order.id == order.id

      assert updated_order.products |> Enum.at(0) |> Map.get(:whcc_processing) !=
               nil
    end
  end

  defp confirmed_product,
    do: %Picsello.Cart.CartProduct{
      base_price: %Money{amount: 17_600, currency: :USD},
      editor_details: %Picsello.WHCC.Editor.Details{
        editor_id: "hkazbRKGjcoWwnEq3",
        preview_url:
          "https://d3fvjqx1d7l6w5.cloudfront.net/a0e912a6-34ef-4963-b04d-5f4a969e2237.jpeg",
        product_id: "f5QQgHg9mAEom37bQ",
        selections: %{
          "display_options" => "no",
          "quantity" => 1,
          "size" => "20x30",
          "surface" => "1_4in_acrylic_with_styrene_backing"
        }
      },
      id: nil,
      price: %Money{amount: 35_200, currency: :USD},
      whcc_confirmation: :confirmed,
      whcc_order: %Picsello.WHCC.Order.Created{
        confirmation: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
        entry: "hkazbRKGjcoWwnEq3",
        products: [
          %{
            "Price" => "176.00",
            "ProductDescription" => "Acrylic Print 1/4\" with Styrene Backing 20x30",
            "Quantity" => 1
          },
          %{
            "Price" => "8.80",
            "ProductDescription" => "Peak Season Surcharge",
            "Quantity" => 1
          },
          %{
            "Price" => "65.60",
            "ProductDescription" => "Fulfillment Shipping WD - NDS or 2 day",
            "Quantity" => 1
          }
        ],
        total: "250.40"
      },
      whcc_processing: nil,
      whcc_tracking: nil
    }

  defp processing_status(id),
    do: %{
      "Status" => "Accepted",
      "Errors" => [],
      "OrderNumber" => 14_989_342,
      "Event" => "Processed",
      "ConfirmationId" => "a3ff9b4a-3112-4101-88ab-6ba025fd7600",
      "EntryId" => id,
      "Reference" => "OrderID 12345"
    }
end
