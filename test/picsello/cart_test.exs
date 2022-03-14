defmodule Picsello.CartTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.{Cart, Repo}
  alias Cart.{Order, Order.Digital, CartProduct}

  defp cart_product(opts) do
    %CartProduct{
      editor_details: %Picsello.WHCC.Editor.Details{
        product_id: Keyword.get(opts, :product_id),
        editor_id: Keyword.get(opts, :editor_id)
      },
      price: Keyword.get(opts, :price, ~M[100]USD)
    }
  end

  describe "place_product" do
    setup do
      photo = insert(:photo)

      digital = %Digital{
        photo_id: photo.id,
        price: ~M[100]USD,
        preview_url: ""
      }

      [gallery: insert(:gallery), photo: photo, digital: digital]
    end

    test "creates an order and adds the digital", %{gallery: %{id: gallery_id}, digital: digital} do
      assert %Order{
               subtotal_cost: ~M[100]USD,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = Cart.place_product(digital, gallery_id)

      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and adds the digital", %{
      gallery: %{id: gallery_id} = gallery,
      digital: digital
    } do
      %{id: order_id} = insert(:order, gallery: gallery)

      assert %Order{
               id: ^order_id,
               subtotal_cost: ~M[100]USD,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = Cart.place_product(digital, gallery_id)

      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and appends the digital",
         %{
           gallery: %{id: gallery_id},
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      digital_2_photo_id = insert(:photo).id
      digital_2 = %{digital | photo_id: digital_2_photo_id}

      Cart.place_product(digital, gallery_id)

      assert %Order{
               subtotal_cost: ~M[200]USD,
               digitals: [%{photo_id: ^digital_2_photo_id}, %{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = Cart.place_product(digital_2, gallery_id)
    end

    test "won't add the same digital twice",
         %{
           gallery: %{id: gallery_id},
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      Cart.place_product(digital, gallery_id)

      assert %Order{
               subtotal_cost: ~M[100]USD,
               digitals: [%{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = Cart.place_product(digital, gallery_id)
    end
  end

  describe "delete_product" do
    setup do
      [order: insert(:order)]
    end

    test "with an editor id and multiple products removes the product", %{order: order} do
      order =
        order
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
        |> Order.update_changeset(cart_product(editor_id: "123", price: ~M[200]USD))
        |> Repo.update!()

      assert {:loaded,
              %Order{
                subtotal_cost: ~M[200]USD,
                products: [%{editor_details: %{editor_id: "123"}}]
              }} = Cart.delete_product(order, editor_id: "abc")
    end

    test "with an editor id and some digitals removes the product", %{order: order} do
      digital = %Digital{
        photo_id: insert(:photo).id,
        price: ~M[100]USD,
        preview_url: ""
      }

      order =
        order
        |> Order.update_changeset(digital)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:loaded,
              %Order{
                subtotal_cost: ~M[100]USD,
                digitals: [cart_digital],
                products: []
              }} = Cart.delete_product(order, editor_id: "abc")

      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "with an editor id and one product deletes the order", %{order: order} do
      order =
        order
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, editor_id: "abc")
      refute Repo.get(Order, order_id)
    end

    test "with a digital id and multiple digitals removes the digital", %{order: order} do
      order =
        order
        |> Order.update_changeset(%Digital{
          photo_id: insert(:photo).id,
          price: ~M[200]USD,
          preview_url: ""
        })
        |> Order.update_changeset(%Digital{
          photo_id: insert(:photo).id,
          price: ~M[100]USD,
          preview_url: ""
        })
        |> Repo.update!()

      %{digitals: [%{id: delete_digital_id}, %{id: remaining_digital_id}]} = order

      assert {:loaded,
              %Order{
                subtotal_cost: ~M[200]USD,
                digitals: [%{id: ^remaining_digital_id}]
              }} = Cart.delete_product(order, digital_id: delete_digital_id)
    end

    test "with a digital id and a product removes the digital", %{order: order} do
      digital = %Digital{
        photo_id: insert(:photo).id,
        price: ~M[100]USD,
        preview_url: ""
      }

      product = cart_product(editor_id: "abc", price: ~M[300]USD)

      %{digitals: [%{id: digital_id}]} =
        order =
        order
        |> Order.update_changeset(digital)
        |> Order.update_changeset(product)
        |> Repo.update!()

      assert {:loaded,
              %Order{
                subtotal_cost: ~M[300]USD,
                digitals: [],
                products: [^product]
              }} = Cart.delete_product(order, digital_id: digital_id)
    end

    test "with a digital id and one digital the order", %{order: order} do
      %{digitals: [%{id: digital_id}]} =
        order =
        order
        |> Order.update_changeset(%Digital{
          photo_id: insert(:photo).id,
          price: ~M[100]USD,
          preview_url: ""
        })
        |> Repo.update!()

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, digital_id: digital_id)
      refute Repo.get(Order, order_id)
    end
  end

  describe "get_unconfirmed_order" do
    test "preloads products" do
      %{gallery_id: gallery_id} =
        insert(:order)
        |> Order.update_changeset(
          cart_product(product_id: insert(:product, whcc_id: "abc").whcc_id)
        )
        |> Repo.update!()

      assert {:ok, %{products: [%{whcc_product: %{whcc_id: "abc"}}]}} =
               Cart.get_unconfirmed_order(gallery_id, :preload_products)
    end
  end

  describe "cart product updates" do
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

  describe "checkout_params" do
    test "returns correct line items" do
      Mox.stub(Picsello.PhotoStorageMock, :path_to_url, fn "digital.jpg" ->
        "https://example.com/digital.jpg"
      end)

      gallery = insert(:gallery)
      whcc_product = insert(:product)

      cart_product = build(:ordered_cart_product, %{product_id: whcc_product.whcc_id})

      order =
        for product <- [cart_product, %Digital{preview_url: "digital.jpg", price: ~M[500]USD}],
            reduce: nil do
          _ ->
            Picsello.Cart.place_product(product, gallery.id)
        end

      checkout_params =
        Cart.checkout_params(%{
          order
          | delivery_info: %{email: "customer@example.com"},
            products:
              Enum.map(
                order.products,
                &%{
                  &1
                  | whcc_product:
                      insert(:product,
                        attribute_categories: [
                          %{
                            "_id" => "size",
                            "attributes" => [%{"id" => "20x30", "name" => "20 by 30"}]
                          }
                        ]
                      )
                }
              )
        })

      assert [
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: [cart_product.editor_details.preview_url],
                     name: "20 by 30 #{whcc_product.whcc_name}"
                   },
                   unit_amount: 35_200
                 },
                 quantity: cart_product.editor_details.selections["quantity"]
               },
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: ["https://example.com/digital.jpg"],
                     name: "Digital image"
                   },
                   unit_amount: 500
                 },
                 quantity: 1
               }
             ] == checkout_params.line_items
    end
  end

  defp confirmed_product(editor_id \\ "hkazbRKGjcoWwnEq3"),
    do: %Picsello.Cart.CartProduct{
      base_price: %Money{amount: 17_600, currency: :USD},
      editor_details: %Picsello.WHCC.Editor.Details{
        editor_id: editor_id,
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
      price: %Money{amount: 35_200, currency: :USD},
      whcc_confirmation: :confirmed,
      whcc_order: %Picsello.WHCC.Order.Created{
        confirmation: "a1f5cf28-b96e-49b5-884d-04b6fb4700e3",
        entry: editor_id,
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
