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

  import Money.Sigils

  setup do
    Mox.verify_on_exit!()

    [
      gallery:
        insert(:gallery,
          job:
            insert(:lead,
              client:
                insert(:client,
                  organization:
                    insert(:organization,
                      user: insert(:user, stripe_customer_id: "photographer-stripe-customer-id")
                    )
                )
            )
        )
    ]
  end

  def insert_order(%{whcc_order: whcc_order, placed_at: placed_at, gallery: gallery}),
    do: [
      order:
        :order
        |> insert(
          delivery_info: %{email: "client@example.com"},
          whcc_order: whcc_order,
          placed_at: placed_at,
          gallery: gallery
        )
        |> Repo.preload([:gallery, :products, :digitals])
    ]

  def insert_order(%{} = context),
    do:
      context
      |> Enum.into(%{whcc_order: build(:whcc_order_created), placed_at: DateTime.utc_now()})
      |> insert_order()

  def insert_invoice(%{order: order}) do
    [
      invoice: insert(:invoice, order: order, status: :open, stripe_id: "invoice-stripe-id"),
      stripe_invoice: build(:stripe_invoice, status: "paid", id: "invoice-stripe-id")
    ]
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

  def insert_intent(%{order: order}) do
    intent =
      insert(:intent,
        stripe_payment_intent_id: "payment-intent-id",
        order: order,
        amount: Order.total_cost(order),
        status: :requires_payment_method
      )

    %{amount: total_cents} = Order.total_cost(order)

    [
      intent: intent,
      stripe_intent:
        build(:stripe_payment_intent,
          id: intent.stripe_payment_intent_id,
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
          payment_intent: intent.stripe_payment_intent_id,
          client_reference_id: "order_number_#{Order.number(order)}"
        )
    ]
  end

  def handle_session(session), do: Confirmations.handle_session(session)

  describe "handle_invoice - paid, no intent" do
    setup [:stub_confirm_order, :insert_order, :insert_invoice]

    test("updates invoice", ctx, do: updates_invoice(ctx))
    test("confirms whcc order", ctx, do: confirms_whcc_order(ctx))
  end

  describe "handle_invoice - paid, unpaid intent" do
    setup [
      :insert_order,
      :insert_invoice,
      :stub_confirm_order,
      :insert_intent,
      :stub_capture_intent
    ]

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
    setup do
      [placed_at: nil]
    end

    setup :insert_order

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
            build(:whcc_order_created,
              orders: build_list(1, :whcc_order_created_order, total: ~M[0]USD)
            )
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
      assert Picsello.Orders.client_paid?(order)

      Picsello.Orders.get_purchased_photos!(Order.number(order), gallery)
    end

    test "confirms order", %{order: order, session: session} do
      assert %{whcc_order: %{confirmed_at: nil} = unconfirmed_whcc_order} = order

      handle_session(session)

      %{whcc_order: %{confirmed_at: confirmed_at} = confirmed_whcc_order} = Repo.reload!(order)

      assert Map.put(unconfirmed_whcc_order, :confirmed_at, confirmed_at) == confirmed_whcc_order
    end
  end

  describe "handle_session - paid, photographer owes" do
    setup do
      invoice = build(:stripe_invoice, id: "invoice-stripe-id")

      MockPayments
      |> Mox.stub(:create_invoice_item, fn _, _ ->
        {:ok, %Stripe.Invoiceitem{}}
      end)
      |> Mox.stub(:create_invoice, fn _, _ ->
        {:ok, invoice}
      end)
      |> Mox.stub(:finalize_invoice, fn _, _, _ ->
        {:ok, %{invoice | status: "open"}}
      end)

      [
        whcc_order: build(:whcc_order_created, total: ~M[60_000]USD),
        placed_at: nil,
        stripe_invoice: invoice
      ]
    end

    setup :insert_order

    setup %{order: %{gallery: gallery} = order} do
      insert(:digital, order: order, photo: insert(:photo, gallery: gallery))

      Picsello.Cart.place_product(build(:cart_product), gallery)

      order = Repo.preload(order, [:digitals, :products], force: true)

      assert :lt ==
               Money.cmp(
                 Order.total_cost(order),
                 Picsello.WHCC.Order.Created.total(order.whcc_order)
               )

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

    test "creates and finalizes invoice", %{
      order: order,
      session: session,
      stripe_invoice: invoice
    } do
      test_pid = self()

      Mox.expect(MockPayments, :finalize_invoice, fn invoice_id, _params, _opts ->
        send(test_pid, {:finalized_invoice_id, invoice_id})
        {:ok, %{invoice | status: "open"}}
      end)

      handle_session(session)

      assert %{stripe_id: invoice_id} = Repo.get_by(Invoice, order_id: order.id)

      assert_receive {:finalized_invoice_id, ^invoice_id}

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
    setup [:insert_order, :insert_intent, :build_session]

    setup %{intent: intent, order: order, stripe_intent: stripe_intent} do
      [
        order: order |> Order.placed_changeset() |> Repo.update!(),
        intent:
          intent |> Intent.changeset(%{stripe_intent | status: :succeeded}) |> Repo.update!()
      ]
    end

    test "is successful", %{order: order, session: session} do
      assert Picsello.Orders.client_paid?(order)

      assert {:ok, _, :already_confirmed} = handle_session(session)
    end
  end

  describe "handle_session - something does wrong" do
    setup [:insert_order, :insert_intent, :build_session]

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
