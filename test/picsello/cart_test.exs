defmodule Picsello.CartTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.{Cart, Repo}
  alias Cart.{Order, Digital}

  defp cart_product(opts) do
    build(:cart_product,
      editor_id: Keyword.get(opts, :editor_id),
      round_up_to_nearest: 100,
      shipping_base_charge: ~M[0]USD,
      shipping_upcharge: Decimal.new(0),
      unit_markup: ~M[0]USD,
      unit_price: Keyword.get(opts, :price, ~M[100]USD),
      whcc_product: insert(:product)
    )
  end

  setup do
    Mox.verify_on_exit!()
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
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } =
               order =
               Cart.place_product(digital, gallery_id) |> Repo.preload(products: :whcc_product)

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and adds the digital", %{
      gallery: %{id: gallery_id} = gallery,
      digital: digital
    } do
      %{id: order_id} = insert(:order, gallery: gallery)

      assert %Order{
               id: ^order_id,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital, gallery_id)

      assert Order.total_cost(order) == ~M[100]USD
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
               digitals: [%{photo_id: ^digital_2_photo_id}, %{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital_2, gallery_id)

      assert Order.total_cost(order) == ~M[200]USD
    end

    test "won't add the same digital twice",
         %{
           gallery: %{id: gallery_id},
           digital: digital
         } do
      order = Cart.place_product(digital, gallery_id)

      assert ~M[100]USD == order |> Repo.preload(:products) |> Order.total_cost()

      assert_raise(Ecto.ConstraintError, fn ->
        Cart.place_product(digital, gallery_id)
      end)

      assert ~M[100]USD ==
               order
               |> Repo.reload!()
               |> Repo.preload([:digitals, :products])
               |> Order.total_cost()
    end
  end

  describe "delete_product" do
    setup do
      [order: insert(:order)]
    end

    test "with an editor id and multiple products removes the product", %{order: order} do
      order =
        order
        |> Repo.preload(:products)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
        |> Repo.update!()
        |> Repo.preload([products: :whcc_product], force: true)
        |> Order.update_changeset(cart_product(editor_id: "123", price: ~M[200]USD))
        |> Repo.update!()
        |> Repo.preload([:digitals, products: :whcc_product], force: true)

      assert {:loaded,
              %Order{
                products: [%{editor_id: "123"}]
              } = order} = Cart.delete_product(order, editor_id: "abc")

      assert Order.total_cost(order) == ~M[200]USD
    end

    test "with an editor id and some digitals removes the product", %{order: order} do
      digital = %Digital{
        photo_id: insert(:photo).id,
        price: ~M[100]USD
      }

      order =
        order
        |> Repo.preload(:digitals)
        |> Order.update_changeset(digital)
        |> Repo.update!()
        |> Repo.preload(products: :whcc_product)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:loaded,
              %Order{
                digitals: [cart_digital],
                products: []
              } = order} = Cart.delete_product(order, editor_id: "abc")

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "with an editor id and one product deletes the order", %{order: order} do
      order =
        order
        |> Repo.preload(products: :whcc_product)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, editor_id: "abc")
      refute Repo.get(Order, order_id)
    end

    test "with a digital id and multiple digitals removes the digital", %{order: order} do
      %{id: delete_digital_id} = insert(:digital, order: order, price: ~M[200]USD)
      %{id: remaining_digital_id} = insert(:digital, order: order, price: ~M[100]USD)

      assert {:loaded,
              %Order{
                digitals: [%{id: ^remaining_digital_id}]
              } = order} =
               order
               |> Repo.preload(:products)
               |> Cart.delete_product(digital_id: delete_digital_id)

      assert Order.total_cost(order) == ~M[100]USD
    end

    test "with a digital id and free and paid digitals removes the free digital and updates the first paid digital to free",
         %{order: order} do
      now = DateTime.utc_now()

      %{id: delete_free_digital_id} =
        insert(:digital, order: order, is_credit: true, inserted_at: now)

      %{id: remaining_digital_id_1} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 1))

      %{id: remaining_digital_id_2} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 2))

      assert {:loaded, order} =
               order
               |> Cart.delete_product(digital_id: delete_free_digital_id)

      assert [
               %{id: ^remaining_digital_id_1, is_credit: false},
               %{id: ^remaining_digital_id_2, is_credit: true}
             ] =
               order.digitals
               |> Enum.map(&Map.take(&1, [:id, :is_credit]))

      assert Order.total_cost(order) == ~M[500]USD
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
        |> Repo.preload(:digitals)
        |> Order.update_changeset(digital)
        |> Repo.update!()
        |> Repo.preload(:products)
        |> Order.update_changeset(product)
        |> Repo.update!()

      assert {:loaded, order} = Cart.delete_product(order, digital_id: digital_id)
      assert [%{editor_id: "abc"}] = order |> Ecto.assoc(:products) |> Repo.all()
      assert Order.total_cost(order) == ~M[300]USD
    end

    test "with a digital id and one digital the order", %{order: order} do
      %{digitals: [%{id: digital_id}]} =
        order =
        order
        |> Repo.preload(:digitals)
        |> Order.update_changeset(%Digital{
          photo_id: insert(:photo).id,
          price: ~M[100]USD,
          preview_url: ""
        })
        |> Repo.update!()
        |> Repo.preload(:products)

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, digital_id: digital_id)
      refute Repo.get(Order, order_id)
    end
  end

  describe "get_unconfirmed_order" do
    test "preloads products" do
      whcc_product = insert(:product, whcc_id: "abc")

      %{gallery_id: gallery_id} =
        insert(:order, products: build_list(1, :cart_product, whcc_product: whcc_product))

      assert {:ok, %{products: [%{whcc_product: %{whcc_id: "abc"}}]}} =
               Cart.get_unconfirmed_order(gallery_id, preload: [:products])
    end
  end

  describe "get_orders" do
    def order_with_product(gallery, opts) do
      whcc_id = Keyword.get(opts, :whcc_id)
      placed_at = Keyword.get(opts, :placed_at, DateTime.utc_now())

      insert(:order,
        gallery: gallery,
        placed_at: placed_at,
        products: build_list(1, :cart_product, whcc_product: build(:product, whcc_id: whcc_id))
      )
    end

    test "preloads products" do
      gallery = insert(:gallery)

      order_with_product(gallery, whcc_id: "123")

      order_with_product(gallery,
        whcc_id: "abc",
        placed_at: DateTime.utc_now() |> DateTime.add(-100)
      )

      assert [
               %{products: [%{whcc_product: %{whcc_id: "123"}}]},
               %{products: [%{whcc_product: %{whcc_id: "abc"}}]}
             ] = Cart.get_orders(gallery.id)
    end
  end

  describe "cart product updates" do
    setup do
      gallery = insert(:gallery)
      cart_product = build(:cart_product)

      order = Cart.place_product(cart_product, gallery.id)

      entry_id =
        order
        |> Order.number()
        |> to_string()

      [
        order:
          order
          |> Order.whcc_order_changeset(
            build(:whcc_order_created, entry_id: entry_id, total: ~M[100]USD)
          )
          |> Repo.update!(),
        entry_id: entry_id
      ]
    end

    def processing_status(entry_id, sequence_number),
      do: %Picsello.WHCC.Webhooks.Status{
        entry_id: entry_id,
        event: "Processed",
        sequence_number: sequence_number,
        status: "Accepted"
      }

    def processing_event(entry_id, sequence_number),
      do: %Picsello.WHCC.Webhooks.Event{
        entry_id: entry_id,
        event: "Shipped",
        sequence_number: sequence_number,
        shipping_info: [
          %Picsello.WHCC.Webhooks.ShippingInfo{
            carrier: "FedEx",
            ship_date: ~U[2018-12-31 12:18:38Z],
            tracking_number: "512376671311227",
            tracking_url: "http://www.fedex.com/Tracking?tracknumbers=512376671311227",
            weight: 0.35
          }
        ]
      }

    test "find and save processing status", %{order: order} do
      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Cart.update_whcc_order(processing_status(entry_id, sequence_number))

      assert %{whcc_order: %{orders: [%{whcc_processing: %{status: "Accepted"}}]}} =
               Repo.reload!(order)
    end

    test "updates correct sub-order", %{order: order, entry_id: entry_id} do
      order =
        order
        |> Order.whcc_order_changeset(
          build(:whcc_order_created,
            entry_id: entry_id,
            orders: build_list(2, :whcc_order_created_order)
          )
        )
        |> Repo.update!()

      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{}, %{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Cart.update_whcc_order(processing_status(entry_id, sequence_number))

      assert %{
               whcc_order: %{
                 orders: [%{whcc_processing: nil}, %{whcc_processing: %{status: "Accepted"}}]
               }
             } = Repo.reload!(order)
    end

    test "works with shipping updates too", %{order: order, entry_id: entry_id} do
      order =
        order
        |> Order.whcc_order_changeset(
          build(:whcc_order_created,
            entry_id: entry_id,
            orders: build_list(2, :whcc_order_created_order)
          )
        )
        |> Repo.update!()

      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{}, %{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Cart.update_whcc_order(processing_event(entry_id, sequence_number))

      assert %{
               whcc_order: %{
                 orders: [%{whcc_tracking: nil}, %{whcc_tracking: %{event: "Shipped"}}]
               }
             } = Repo.reload!(order)
    end
  end

  describe "checkout_params" do
    test "returns correct line items" do
      Mox.stub(Picsello.PhotoStorageMock, :path_to_url, fn "digital.jpg" ->
        "https://example.com/digital.jpg"
      end)

      gallery = insert(:gallery)
      whcc_product = insert(:product)

      cart_product = build(:cart_product, whcc_product: whcc_product)

      order =
        for product <-
              [
                cart_product,
                build(:digital,
                  price: ~M[500]USD,
                  photo:
                    insert(:photo, gallery: gallery, preview_url: "digital.jpg")
                    |> Map.put(:watermarked, false)
                )
              ],
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

      quantity = cart_product.selections["quantity"]

      assert [
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: [cart_product.preview_url],
                     tax_code: "txcd_99999999",
                     name: "20 by 30 #{whcc_product.whcc_name} (Qty #{quantity})"
                   },
                   unit_amount:
                     cart_product
                     |> Cart.Product.update_price(shipping_base_charge: true)
                     |> Cart.Product.charged_price()
                     |> Map.get(:amount),
                   tax_behavior: "exclusive"
                 },
                 quantity: quantity
               },
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: ["https://example.com/digital.jpg"],
                     name: "Digital image",
                     tax_code: "txcd_10501000"
                   },
                   unit_amount: 500,
                   tax_behavior: "exclusive"
                 },
                 quantity: 1
               }
             ] == checkout_params.line_items
    end
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

      %{gallery_id: gallery_id} = order = insert(:order, products: cart_products)

      [
        cart_products: cart_products,
        order: Cart.preload_products(order),
        account_id: Picsello.Galleries.account_id(gallery_id),
        order_number: Cart.Order.number(order)
      ]
    end

    test "exports editors, providing shipping information", %{
      order: order,
      account_id: account_id,
      order_number: order_number,
      cart_products: cart_products
    } do
      Picsello.MockWHCCClient
      |> Mox.expect(:editors_export, fn ^account_id, editors, opts ->
        assert cart_products |> Enum.map(& &1.editor_id) |> MapSet.new() ==
                 editors |> Enum.map(& &1.id) |> MapSet.new()

        assert to_string(order_number) == Keyword.get(opts, :entry_id)

        %Picsello.WHCC.Editor.Export{}
      end)
      |> Mox.expect(:create_order, fn ^account_id, _export ->
        build(:whcc_order_created)
      end)

      Cart.create_whcc_order(order)
    end
  end

  describe "confirm_order" do
    def confirm_order(session) do
      Cart.confirm_order(
        session,
        PicselloWeb.Helpers
      )
    end

    test "raises if order does not exist" do
      assert_raise(Ecto.NoResultsError, fn ->
        confirm_order(%Stripe.Session{
          client_reference_id: "order_number_404"
        })
      end)
    end

    test "is successful when order is already confirmed" do
      order = insert(:order, placed_at: DateTime.utc_now())

      assert {:ok, _} =
               confirm_order(%Stripe.Session{
                 client_reference_id: "order_number_#{Order.number(order)}"
               })
    end

    test "cancels payment intent on failure" do
      order = insert(:order) |> Repo.preload(:digitals)

      Picsello.MockPayments
      |> Mox.expect(:retrieve_payment_intent, fn "intent-id", _stripe_options ->
        {:ok, %{amount_capturable: Order.total_cost(Repo.preload(order, :products)).amount + 1}}
      end)
      |> Mox.expect(:cancel_payment_intent, fn "intent-id", _stripe_options -> nil end)

      confirm_order(%Stripe.Session{
        client_reference_id: "order_number_#{Order.number(order)}",
        payment_intent: "intent-id"
      })
    end
  end

  describe "print_credit_used" do
    def create_gallery(opts \\ []),
      do: insert(:gallery, job: insert(:lead, package: insert(:package, opts)))

    def create_order(opts \\ []) do
      {total, opts} = Keyword.pop(opts, :total, ~M[0]USD)

      %{id: gallery_id} = Keyword.get_lazy(opts, :gallery, fn -> create_gallery(opts) end)

      Cart.place_product(
        build(:cart_product,
          shipping_base_charge: ~M[0]USD,
          shipping_upcharge: 0,
          unit_markup: ~M[0]USD,
          unit_price: total
        ),
        gallery_id
      )
    end

    def print_credit_used(%{products: products}),
      do: Enum.reduce(products, ~M[0]USD, &Money.add(&2, &1.print_credit_discount))

    test "zero when no print credit in package" do
      assert ~M[0]USD =
               create_order(print_credits: nil, total: ~M[1000]USD) |> print_credit_used()
    end

    test "zero when credit is used up" do
      gallery = create_gallery(print_credits: ~M[500]USD)
      create_order(gallery: gallery, total: ~M[600]USD)
      order = create_order(gallery: gallery, total: ~M[1000]USD)

      assert ~M[0]USD = print_credit_used(order)
    end

    test "order price when more credit than needed" do
      assert ~M[1000]USD =
               create_order(print_credits: ~M[1900]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "order price when exactly right credit" do
      assert ~M[1000]USD =
               create_order(print_credits: ~M[1000]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "remaining credit when not enough to cover order" do
      assert ~M[900]USD =
               create_order(print_credits: ~M[900]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end
  end
end
