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
      build(:whcc_editor_export, order_sequence_number: sequence_number)
    end)
    |> Mox.stub(:create_order, fn _, _ -> {:ok, whcc_order} end)

    :ok
  end

  def stub_create_session(_) do
    Mox.stub(MockPayments, :create_session, fn _, _ ->
      {:ok, build(:stripe_session)}
    end)

    :ok
  end

  def stub_create_invoice(_) do
    MockPayments
    |> Mox.stub(:create_invoice_item, fn _, _ ->
      {:ok, %Stripe.Invoiceitem{}}
    end)
    |> Mox.stub(:create_invoice, fn _, _ ->
      {:ok, build(:stripe_invoice)}
    end)

    :ok
  end

  def stub_finalize_invoice(_) do
    Mox.stub(MockPayments, :finalize_invoice, fn _, _, _ ->
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
    Mox.expect(MockPayments, :create_session, fn _params, _opts ->
      {:ok,
       build(:stripe_session,
         payment_intent: build(:stripe_payment_intent, id: "intent-stripe-id")
       )}
    end)

    assert {:ok, _} = check_out(order)
    assert [%Intent{stripe_id: "intent-stripe-id"}] = Repo.all(Intent)
  end

  def creates_whcc_order(%{order: order, whcc_order: whcc_order}) do
    Mox.expect(MockWHCCClient, :create_order, fn _, _ ->
      {:ok, whcc_order}
    end)

    assert {:ok, _} = check_out(order)

    assert [%{whcc_order: %Picsello.WHCC.Order.Created{entry_id: "whcc-entry-id"}}] =
             Repo.all(Order)
  end

  def creates_invoice(%{order: order}) do
    Mox.expect(MockPayments, :create_invoice, fn _params, _opts ->
      {:ok, build(:stripe_invoice, id: "invoice-stripe-id")}
    end)

    assert {:ok, _} = check_out(order)
    assert [%Invoice{stripe_id: "invoice-stripe-id"}] = Repo.all(Invoice)
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

    test("creates invoice", context, do: creates_invoice(context))
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

    setup [:stub_create_order, :stub_create_invoice, :stub_finalize_invoice]

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

    test("creates invoice", context, do: creates_invoice(context))

    test "finalizes invoice", %{order: order} do
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

      Checkouts.create_whcc_order(Picsello.Repo, %{product_order: order})
    end
  end
end
