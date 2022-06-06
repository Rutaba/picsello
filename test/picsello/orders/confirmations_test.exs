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

    order =
      insert(:order,
        delivery_info: %{email: "client@example.com"},
        whcc_order: build(:whcc_order_created),
        placed_at: DateTime.utc_now()
      )

    [
      invoice:
        insert(:invoice,
          order: order,
          status: :open,
          stripe_id: "invoice-stripe-id"
        ),
      order: Repo.preload(order, [:gallery, :products, :digitals]),
      stripe_invoice: build(:stripe_invoice, status: "paid", id: "invoice-stripe-id")
    ]
  end

  def stub_confirm_order(_) do
    Mox.stub(MockWHCCClient, :confirm_order, fn _, _ ->
      {:ok, :confirmed}
    end)

    :ok
  end

  def stub_capture_intent(_) do
    Mox.stub(MockPayments, :capture_payment_intent, fn _, _ ->
      {:ok, build(:stripe_payment_intent, id: "payment-intent-id")}
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

  def handle_session(session), do: Confirmations.handle_session(session, PicselloWeb.Helpers)

  describe "handle_invoice - paid, no intent" do
    setup :stub_confirm_order

    test("updates invoice", ctx, do: updates_invoice(ctx))
    test("confirms whcc order", ctx, do: confirms_whcc_order(ctx))
  end

  describe "handle_invoice - paid, unpaid intent" do
    setup [:stub_confirm_order, :stub_capture_intent]

    setup %{order: order} do
      [
        intent:
          insert(:intent, stripe_id: "payment-intent-id", order: order, status: :requires_capture)
      ]
    end

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

  describe "handle_session - paid, unpaid invoice" do
    setup %{order: %{gallery: gallery} = order} do
      insert(:digital, order: order, photo: insert(:photo, gallery: gallery))

      order = Repo.preload(order, [:digitals], force: true)

      refute Picsello.Orders.photographer_paid?(order)

      intent =
        insert(:intent,
          stripe_id: "payment-intent-id",
          order: order,
          amount: Order.total_cost(order)
        )

      stripe_intent =
        build(:stripe_payment_intent,
          id: intent.stripe_id,
          amount: Order.total_cost(order).amount
        )

      Mox.expect(MockPayments, :retrieve_payment_intent, fn _params, _opts ->
        {:ok,
         %{stripe_intent | status: "requires_capture", amount_capturable: stripe_intent.amount}}
      end)

      [
        intent: intent,
        session:
          build(:stripe_session,
            payment_intent: intent.stripe_id,
            client_reference_id: "order_number_#{Order.number(order)}"
          )
      ]
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
    test "is successful", %{order: order, invoice: invoice} do
      invoice |> Invoice.changeset(build(:stripe_invoice, status: "paid")) |> Repo.update!()

      assert Picsello.Orders.photographer_paid?(order)
      assert Picsello.Orders.client_paid?(order)

      assert {:ok, _} =
               build(:stripe_session, client_reference_id: "order_number_#{Order.number(order)}")
               |> handle_session()
    end
  end

  describe "handle_session - something does wrong" do
    test "cancels payment intent" do
      order = insert(:order, placed_at: DateTime.utc_now()) |> Repo.preload(:digitals)
      insert(:intent, order: order)

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
