defmodule Picsello.Orders.ConfirmationsTest do
  use Picsello.DataCase, async: true

  alias Picsello.{
    MockPayments,
    Orders.Confirmations,
    MockWHCCClient,
    Cart.Order,
    Invoices.Invoice,
    Intents.Intent
  }

  setup do
    Mox.verify_on_exit!()

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    gallery = insert(:gallery)

    order =
      insert(:order,
        delivery_info: %{email: "client@example.com"},
        whcc_order: build(:whcc_order_created),
        gallery: gallery
      )

    [gallery: gallery, order: Repo.preload(order, [:gallery, :products, :digitals])]
  end

  def stub_confirm_order(_) do
    Mox.stub(MockWHCCClient, :confirm_order, fn _, _ ->
      {:ok, :confirmed}
    end)

    :ok
  end

  def stub_capture_intent(%{stripe_intent: stripe_intent}) do
    Mox.stub(MockPayments, :capture_payment_intent, fn _, _ ->
      {:ok, %{stripe_intent | status: "succeeded"}}
    end)

    :ok
  end

  def insert_invoice(%{order: order}) do
    [
      invoice: insert(:invoice, order: order, status: :open, stripe_id: "invoice-stripe-id"),
      stripe_invoice: build(:stripe_invoice, status: "paid", id: "invoice-stripe-id")
    ]
  end

  def insert_intent(%{order: order}) do
    intent =
      insert(:intent,
        stripe_id: "payment-intent-id",
        order: order,
        amount: Order.total_cost(order),
        status: :requires_payment_method
      )

    %{amount: total_cents} = Order.total_cost(order)

    [
      intent: intent,
      stripe_intent:
        build(:stripe_payment_intent,
          id: intent.stripe_id,
          amount: total_cents,
          status: "requires_capture",
          amount_capturable: total_cents
        )
    ]
  end

  def stub_retrieve_intent(%{stripe_intent: stripe_intent}) do
    Mox.stub(MockPayments, :retrieve_payment_intent, fn _, _ ->
      {:ok, stripe_intent}
    end)

    :ok
  end

  def updates_invoice(%{stripe_invoice: stripe_invoice}) do
    assert {:ok, _} = Confirmations.handle_invoice(stripe_invoice)
    assert [%Invoice{status: :paid}] = Repo.all(Invoice)
  end

  def confirms_whcc_order(%{stripe_invoice: stripe_invoice}) do
    Mox.expect(MockWHCCClient, :confirm_order, fn _, _ ->
      {:ok, :confirmed}
    end)

    assert {:ok, _} = Confirmations.handle_invoice(stripe_invoice)
    assert [%{whcc_order: %{confirmed_at: %DateTime{}}}] = Repo.all(Order)
  end

  def build_session(%{order: order, intent: intent}) do
    [
      session:
        build(:stripe_session,
          payment_intent: intent.stripe_id,
          client_reference_id: "order_number_#{Order.number(order)}"
        )
    ]
  end

  def handle_session(session), do: Confirmations.handle_session(session)

  describe "handle_invoice - paid, no intent" do
    setup [:insert_invoice, :stub_confirm_order]

    test("updates invoice", ctx, do: updates_invoice(ctx))
    test("confirms whcc order", ctx, do: confirms_whcc_order(ctx))
  end

  describe "handle_invoice - paid, unpaid intent" do
    setup [:insert_invoice, :stub_confirm_order, :insert_intent, :stub_capture_intent]

    test("updates invoice", ctx, do: updates_invoice(ctx))
    test("confirms whcc order", ctx, do: confirms_whcc_order(ctx))

    test "captures intent", %{stripe_invoice: stripe_invoice} do
      Mox.expect(MockPayments, :capture_payment_intent, fn _, _ ->
        {:ok, build(:stripe_payment_intent, status: "succeeded", id: "payment-intent-id")}
      end)

      assert {:ok, _} = Confirmations.handle_invoice(stripe_invoice)

      assert [%Intent{status: :succeeded}] = Repo.all(Intent)
    end
  end

  describe "handle_session - paid, with products" do
    setup %{gallery: gallery, order: order} do
      Picsello.Cart.place_product(build(:cart_product), gallery)

      Picsello.Cart.place_product(
        build(:digital, photo: insert(:photo, gallery: gallery)),
        gallery
      )

      [
        order:
          order
          |> Order.whcc_order_changeset(
            build(:whcc_order_created, orders: build_list(1, :whcc_order_created_order))
          )
          |> Repo.update!()
          |> Repo.preload([:digitals, :products], force: true)
      ]
    end

    setup [
      :stub_confirm_order,
      :insert_intent,
      :stub_retrieve_intent,
      :stub_capture_intent,
      :build_session
    ]

    test "updates intent", %{intent: intent, session: session} do
      handle_session(session)

      assert %{status: :succeeded} = Repo.reload!(intent)
    end

    test "makes digitals available", %{
      order: %{gallery: gallery} = order,
      session: session
    } do
      handle_session(session)

      Picsello.Orders.get_purchased_photos!(Order.number(order), gallery)
    end

    test "confirms order", %{order: order, session: session} do
      assert %{whcc_order: %{confirmed_at: nil} = unconfirmed_whcc_order} = order

      handle_session(session)

      %{whcc_order: %{confirmed_at: confirmed_at} = confirmed_whcc_order} = Repo.reload!(order)

      assert Map.put(unconfirmed_whcc_order, :confirmed_at, confirmed_at) == confirmed_whcc_order
    end
  end

  describe "handle_session - paid, unpaid invoice" do
    setup :insert_invoice

    setup %{gallery: gallery, order: order} do
      insert(:digital, order: order, photo: insert(:photo, gallery: gallery))

      order = Repo.preload(order, [:digitals], force: true)

      refute Picsello.Orders.photographer_paid?(order)

      [order: order]
    end

    setup [:insert_intent, :stub_retrieve_intent, :build_session]

    setup %{order: order} do
      refute Picsello.Orders.client_paid?(order)

      MockPayments
      |> Mox.stub(:finalize_invoice, fn invoice_id, _params, _opts ->
        {:ok, build(:stripe_invoice, id: invoice_id, status: "open")}
      end)

      :ok
    end

    test "updates intent", %{intent: intent, session: session} do
      handle_session(session)

      assert %{status: :requires_capture} = Repo.reload!(intent)
    end

    test "makes digitals available", %{
      order: %{gallery: gallery} = order,
      session: session
    } do
      handle_session(session)

      Picsello.Orders.get_purchased_photos!(Order.number(order), gallery)
    end

    test "finalizes invoice", %{invoice: %{stripe_id: invoice_id}, session: session} do
      Mox.expect(MockPayments, :finalize_invoice, fn ^invoice_id, _params, _opts ->
        {:ok, build(:stripe_invoice, id: invoice_id, status: "open")}
      end)

      handle_session(session)

      assert [%{status: :open}] = Repo.all(Invoice)
    end
  end

  describe "handle_session - order does not exist" do
    test "raises" do
      assert_raise(Ecto.NoResultsError, fn ->
        handle_session(%Stripe.Session{
          client_reference_id: "order_number_404"
        })
      end)
    end
  end

  describe "handle_session - order already paid for" do
    setup [:insert_intent, :build_session]

    setup %{intent: intent, order: order, stripe_intent: stripe_intent} do
      [
        order: order |> Order.placed_changeset() |> Repo.update!(),
        intent:
          intent |> Intent.changeset(%{stripe_intent | status: :succeeded}) |> Repo.update!()
      ]
    end

    test "is successful", %{order: order, session: session} do
      assert Picsello.Orders.photographer_paid?(order)
      assert Picsello.Orders.client_paid?(order)

      assert {:ok, _, :already_confirmed} = handle_session(session)
    end
  end

  describe "handle_session - something does wrong" do
    setup [:insert_intent, :build_session]

    test "cancels payment intent", %{order: order} do
      Picsello.MockPayments
      |> Mox.expect(:retrieve_payment_intent, fn "intent-id", _stripe_options ->
        {:ok, %{amount_capturable: Order.total_cost(Repo.preload(order, :products)).amount + 1}}
      end)
      |> Mox.expect(:cancel_payment_intent, fn "intent-id", _stripe_options -> nil end)

      handle_session(%Stripe.Session{
        client_reference_id: "order_number_#{Order.number(order)}",
        payment_intent: "intent-id"
      })
    end
  end
end
