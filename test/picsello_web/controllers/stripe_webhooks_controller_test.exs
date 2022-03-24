defmodule PicselloWeb.StripeWebhooksControllerTest do
  use PicselloWeb.ConnCase, async: true
  alias Picsello.{Repo, PaymentSchedule, Cart.Order}
  import Money.Sigils

  def stub_event(opts) do
    Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
      {:ok,
       %{
         type: "checkout.session.completed",
         data: %{
           object:
             %Stripe.Session{
               metadata: %{"paying_for" => Keyword.get(opts, :paying_for)}
             }
             |> Map.merge(
               opts
               |> Enum.into(%{})
               |> Map.take(~w(payment_status payment_intent client_reference_id)a)
             )
         }
       }}
    end)
  end

  def make_request(conn) do
    conn
    |> put_req_header("stripe-signature", "love, stripe")
    |> post(Routes.stripe_webhooks_path(conn, :connect_webhooks), %{})
  end

  setup do
    user = insert(:user)

    job = insert(:lead, user: user) |> promote_to_job()

    Mox.verify_on_exit!()
    [user: user, job: job]
  end

  describe "proposals" do
    setup %{job: job} do
      job = Repo.preload(job, :payment_schedules)
      proposal = insert(:proposal, job: job)
      [deposit_payment, remainder_payment] = job.payment_schedules

      Repo.update_all(PaymentSchedule, set: [paid_at: nil])

      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

      [
        proposal: proposal,
        job: job,
        deposit_payment: deposit_payment,
        remainder_payment: remainder_payment
      ]
    end

    test "deposit - emails photographer", %{
      conn: conn,
      deposit_payment: deposit_payment,
      proposal: proposal,
      user: %{email: user_email}
    } do
      stub_event(client_reference_id: "proposal_#{proposal.id}", paying_for: deposit_payment.id)
      make_request(conn)

      assert_receive {:delivered_email, %{to: [nil: ^user_email]}}
    end

    test "deposit - marks payment schedule as paid", %{
      conn: conn,
      proposal: proposal,
      deposit_payment: deposit_payment
    } do
      stub_event(client_reference_id: "proposal_#{proposal.id}", paying_for: deposit_payment.id)
      make_request(conn)

      assert %{paid_at: %DateTime{}} = deposit_payment |> Repo.reload!()
    end

    test "remainder - marks booking proposal as paid", %{
      conn: conn,
      proposal: proposal,
      deposit_payment: deposit_payment,
      remainder_payment: remainder_payment
    } do
      deposit_payment |> PaymentSchedule.paid_changeset() |> Repo.update!()

      stub_event(client_reference_id: "proposal_#{proposal.id}", paying_for: remainder_payment.id)

      make_request(conn)

      assert %{paid_at: %DateTime{}} = remainder_payment |> Repo.reload!()
    end
  end

  describe "order webhook" do
    setup do
      organization = insert(:organization, stripe_account_id: "connect-account-id")

      gallery =
        insert(:gallery, job: insert(:lead, client: insert(:client, organization: organization)))

      order = insert(:order, gallery: gallery, subtotal_cost: ~M[0]USD, shipping_cost: ~M[0]USD)

      stub_event(
        client_reference_id: "order_number_#{Order.number(order)}",
        payment_status: "paid",
        payment_intent: "order-payment-intent-id"
      )

      Mox.expect(
        Picsello.MockPayments,
        :capture_payment_intent,
        fn "order-payment-intent-id", connect_account: "connect-account-id" ->
          {:ok, %Stripe.PaymentIntent{status: "succeeded"}}
        end
      )

      [order: order, gallery: gallery]
    end

    test "marks order as paid", %{conn: conn, order: order} do
      Picsello.MockPayments
      |> Mox.expect(:retrieve_payment_intent, fn "order-payment-intent-id",
                                                 connect_account: "connect-account-id" ->
        {:ok, %Stripe.PaymentIntent{amount_capturable: 0}}
      end)

      make_request(conn)

      assert %{placed_at: %DateTime{}} = Repo.reload!(order)
    end

    test "tells WHCC", %{conn: conn, order: order, gallery: gallery} do
      cart_product =
        build(:cart_product,
          price: ~M[1000]USD,
          whcc_order: build(:whcc_order_created, confirmation: "whcc-order-created-id")
        )

      Mox.expect(
        Picsello.MockPayments,
        :retrieve_payment_intent,
        fn "order-payment-intent-id", connect_account: "connect-account-id" ->
          {:ok, %Stripe.PaymentIntent{amount_capturable: 1000}}
        end
      )

      order = order |> Order.update_changeset(cart_product) |> Repo.update!()

      "" <> account_id = Picsello.Galleries.account_id(gallery)

      Mox.expect(
        Picsello.MockWHCCClient,
        :confirm_order,
        fn ^account_id, "whcc-order-created-id" ->
          "whcc-order-confirmed-id"
        end
      )

      make_request(conn)

      assert %{products: [%{whcc_confirmation: "whcc-order-confirmed-id"}]} = Repo.reload!(order)
    end
  end
end
