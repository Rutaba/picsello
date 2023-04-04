defmodule Picsello.Cart.CheckoutsTest do
  use Picsello.DataCase, async: true
  import Money.Sigils

  alias Picsello.{
    Galleries,
    MockPayments,
    Intents.Intent,
    Invoices.Invoice,
    Cart.Order,
    WHCC.Editor.Export,
    MockWHCCClient,
    Cart.Checkouts,
    Cart,
    Repo
  }

  alias Picsello.WHCC.Order.Created, as: WHCCOrder

  setup do
    Mox.verify_on_exit!()

    gallery = insert(:gallery)

    order = insert(:order, delivery_info: %{email: "client@example.com"}, gallery: gallery)

    [gallery: gallery, order: order]
  end

  def stub_create_order(%{
        whcc_order: %{orders: [%{sequence_number: sequence_number}]} = whcc_order
      }) do
    MockWHCCClient
    |> Mox.stub(:editors_export, fn _, _, _ ->
      build(:whcc_editor_export,
        order_sequence_number: sequence_number,
        order: %{
          "Orders" => [
            %{
              "DropShipFlag" => 1,
              "FromAddressValue" => 2,
              "OrderAttributes" => [%{"AttributeUID" => 96}, %{"AttributeUID" => 546}]
            }
          ]
        }
      )
    end)
    |> Mox.stub(:create_order, fn _, _ -> {:ok, whcc_order} end)

    :ok
  end

  def stub_create_order(_),
    do: stub_create_order(%{whcc_order: build(:whcc_order_created, total: ~M[1000]USD)})

  def stub_create_session(_) do
    Mox.stub(MockPayments, :create_session, fn params, _ ->
      {:ok,
       build(
         :stripe_session,
         payment_intent: build(:stripe_payment_intent, Map.get(params, :payment_intent_data, %{}))
       )}
    end)

    :ok
  end

  def stub_create_invoice(_) do
    MockPayments
    |> Mox.stub(:create_customer, fn %{}, _opts ->
      {:ok, %Stripe.Customer{id: "cus_123"}}
    end)
    |> Mox.stub(:create_invoice_item, fn _, _ ->
      {:ok, %Stripe.Invoiceitem{}}
    end)
    |> Mox.stub(:create_invoice, fn _, _ ->
      {:ok, build(:stripe_invoice)}
    end)
    |> Mox.stub(:finalize_invoice, fn _, _, _ ->
      {:ok, build(:stripe_invoice, status: "open")}
    end)

    :ok
  end

  def check_out(%{id: order_id}) do
    Checkouts.check_out(order_id, %{
      "success_url" => "https://example.com",
      "cancel_url" => "https://example.com"
    })
  end

  def creates_a_session_and_saves_the_intent(%{order: order}) do
    Mox.expect(MockPayments, :create_session, fn %{payment_intent_data: payment_intent_data},
                                                 _opts ->
      {:ok,
       build(:stripe_session,
         payment_intent:
           build(:stripe_payment_intent, Map.put(payment_intent_data, :id, "intent-stripe-id"))
       )}
    end)

    assert {:ok, _} = check_out(order)
    assert [%Intent{stripe_payment_intent_id: "intent-stripe-id"}] = Repo.all(Intent)
  end

  def creates_whcc_order(%{order: order, whcc_order: whcc_order}) do
    Mox.expect(MockWHCCClient, :create_order, fn _, _ ->
      {:ok, whcc_order}
    end)

    assert {:ok, _} = check_out(order)

    assert [%{whcc_order: %Picsello.WHCC.Order.Created{entry_id: "whcc-entry-id"}}] =
             Repo.all(Order)
  end

  describe "check_out - second checkout, first still unpaid by client" do
    setup [:stub_create_session]

    setup %{gallery: gallery} do
      order = build(:digital) |> Cart.place_product(gallery)

      refute ~M[0]USD == Order.total_cost(order)

      assert {:ok, _} = check_out(order)
      [order: order]
    end

    test "exipres previous session", %{order: order} do
      MockPayments
      |> Mox.expect(:retrieve_payment_intent, fn id, _ ->
        {:ok, build(:stripe_payment_intent, id: id)}
      end)
      |> Mox.expect(:expire_session, fn id, _ ->
        {:ok, build(:stripe_session, id: id, status: "expired")}
      end)

      check_out(order)
    end
  end

  describe "check_out - client owes, whcc outstanding" do
    setup do
      [whcc_order: build(:whcc_order_created, entry_id: "whcc-entry-id", total: ~M[500000]USD)]
    end

    setup [:stub_create_session, :stub_create_order, :stub_create_invoice]

    setup %{gallery: gallery, whcc_order: whcc_order} do
      order = build(:cart_product) |> Cart.place_product(gallery) |> Repo.preload(:digitals)

      refute ~M[0]USD == Order.total_cost(order)

      assert :lt = Money.cmp(Order.total_cost(order), WHCCOrder.total(whcc_order))

      [order: order]
    end

    test("creates a session and saves the intent", context,
      do: creates_a_session_and_saves_the_intent(context)
    )

    test("creates whcc order", context, do: creates_whcc_order(context))
  end

  describe "check_out - client owes, no products" do
    setup [:stub_create_session]

    setup %{gallery: gallery} do
      order = build(:digital) |> Cart.place_product(gallery)

      refute ~M[0]USD == Order.total_cost(order)

      [order: order]
    end

    test("creates a session and saves the intent", context,
      do: creates_a_session_and_saves_the_intent(context)
    )
  end

  describe "check_out - client owes, whcc not outstanding, products" do
    setup do
      [whcc_order: build(:whcc_order_created, total: ~M[69], entry_id: "whcc-entry-id")]
    end

    setup [:stub_create_session, :stub_create_order]

    setup %{gallery: gallery, whcc_order: whcc_order} do
      order = build(:cart_product) |> Cart.place_product(gallery) |> Repo.preload(:digitals)

      refute ~M[0]USD == Order.total_cost(order)

      assert :gt = Money.cmp(Order.total_cost(order), WHCCOrder.total(whcc_order))

      [order: order]
    end

    test("creates a session and saves the intent", context,
      do: creates_a_session_and_saves_the_intent(context)
    )

    test("creates whcc order", context, do: creates_whcc_order(context))
  end

  describe "check_out - client does not owe, whcc outstanding" do
    setup do
      [whcc_order: build(:whcc_order_created, entry_id: "whcc-entry-id", total: ~M[500000]USD)]
    end

    setup [:stub_create_order, :stub_create_invoice]

    setup %{gallery: gallery, whcc_order: whcc_order} do
      order =
        build(:cart_product,
          shipping_base_charge: ~M[0]USD,
          unit_price: ~M[0]USD,
          unit_markup: ~M[0]USD
        )
        |> Cart.place_product(gallery)
        |> Repo.preload(:digitals)

      assert ~M[0]USD == Order.total_cost(order)

      assert :lt = Money.cmp(Order.total_cost(order), WHCCOrder.total(whcc_order))

      [order: order]
    end

    test("creates whcc order", context, do: creates_whcc_order(context))

    test "creates finalized invoice", %{order: order} do
      Mox.expect(MockPayments, :finalize_invoice, fn _, _, _ ->
        {:ok, build(:stripe_invoice, status: "open")}
      end)

      assert {:ok, _} = check_out(order)

      assert [%Invoice{status: :open}] = Repo.all(Invoice)
    end
  end

  describe "check_out - client does not owe, no products" do
    setup %{gallery: gallery} do
      order =
        build(:digital, price: ~M[0]USD)
        |> Cart.place_product(gallery)

      assert ~M[0] = Order.total_cost(order)

      [order: order]
    end

    test "places the order", %{order: order} do
      assert {:ok, _} = check_out(order)
      assert [%Order{placed_at: %DateTime{}}] = Repo.all(Order)
    end
  end

  describe "stripe session params" do
    setup [:stub_create_order, :stub_create_invoice]

    test "returns correct line items", %{gallery: gallery} do
      Mox.expect(Picsello.PhotoStorageMock, :path_to_url, fn "digital.jpg" ->
        "https://example.com/digital.jpg"
      end)

      test_pid = self()

      Mox.expect(Picsello.MockPayments, :create_session, fn params, _opts ->
        send(test_pid, {:create_session, params})

        {:ok,
         build(:stripe_session,
           payment_intent: build(:stripe_payment_intent, application_fee_amount: ~M[10]USD)
         )}
      end)

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
            Picsello.Cart.place_product(product, gallery)
        end

      check_out(order)

      quantity = cart_product.selections["quantity"]

      assert_receive({:create_session, checkout_params})

      assert [
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: [cart_product.preview_url],
                     tax_code: "txcd_99999999",
                     name: "20×30 #{whcc_product.whcc_name} (Qty #{quantity})"
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
    setup %{gallery: gallery, order: order} do
      cart_products =
        for {product, index} <-
              Enum.with_index([insert(:product) | List.duplicate(insert(:product), 2)]) do
          build(:cart_product,
            whcc_product: product,
            inserted_at: DateTime.utc_now() |> DateTime.add(index)
          )
        end

      order =
        for product <- cart_products, reduce: order do
          _order -> Cart.place_product(product, gallery)
        end

      [
        cart_products: cart_products,
        order: order,
        account_id: Galleries.account_id(gallery),
        order_number: Order.number(order)
      ]
    end

    setup [:stub_create_session]

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
        {:ok, build(:whcc_order_created)}
      end)

      check_out(order)
    end
  end
end
