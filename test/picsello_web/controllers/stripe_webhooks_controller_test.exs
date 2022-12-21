defmodule PicselloWeb.StripeWebhooksControllerTest do
  use PicselloWeb.ConnCase, async: true
  alias Picsello.{Repo, PaymentSchedule, Cart.Order}
  import Money.Sigils
  import ExUnit.CaptureLog

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

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    Mox.verify_on_exit!()
    [user: user, job: job]
  end

  describe "proposals" do
    setup %{job: job} do
      job = Repo.preload(job, :payment_schedules)
      proposal = insert(:proposal, job: job)
      [deposit_payment, remainder_payment] = job.payment_schedules

      Repo.update_all(PaymentSchedule, set: [paid_at: nil])

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

  describe "orders" do
    def intent,
      do: %Stripe.PaymentIntent{
        amount: 0,
        amount_capturable: 0,
        amount_received: 0,
        id: "order-payment-intent-id",
        status: "requires_capture"
      }

    setup do
      organization = insert(:organization, stripe_account_id: "connect-account-id")
      _photographer = insert(:user, organization: organization)

      client = insert(:client, organization: organization)

      gallery = insert(:gallery, job: insert(:lead, client: client))

      order =
        insert(:order,
          gallery: gallery,
          delivery_info: %{email: "client@example.com"}
        )

      insert(:intent, order: order, stripe_payment_intent_id: intent().id)

      stub_event(
        client_reference_id: "order_number_#{Order.number(order)}",
        payment_status: "paid",
        payment_intent: "order-payment-intent-id"
      )

      [order: order, gallery: gallery, client: client, organization: organization]
    end

    def expect_capture,
      do:
        Mox.expect(
          Picsello.MockPayments,
          :capture_payment_intent,
          fn "order-payment-intent-id", connect_account: "connect-account-id" ->
            {:ok, %{intent() | status: "succeeded"}}
          end
        )

    def expect_retrieve(%{amount: amount}),
      do:
        Mox.expect(
          Picsello.MockPayments,
          :retrieve_payment_intent,
          fn "order-payment-intent-id", connect_account: "connect-account-id" ->
            {:ok, %{intent() | amount: amount, amount_capturable: amount}}
          end
        )

    def add_cart_product(order, price),
      do:
        order
        |> Repo.preload(:products)
        |> Order.update_changeset(
          build(:cart_product,
            shipping_base_charge: ~M[0]USD,
            shipping_upcharge: Decimal.new(0),
            unit_markup: ~M[0]USD,
            unit_price: price,
            whcc_product: insert(:product)
          )
        )
        |> Repo.update!()
        |> Order.whcc_order_changeset(
          build(:whcc_order_created, confirmation_id: "whcc-order-created-id")
        )
        |> Repo.update!()
        |> Repo.preload(products: :whcc_product)

    test "marks order as paid", %{conn: conn, order: order} do
      insert(:digital, order: order, price: ~M[10]USD)
      expect_retrieve(~M[10]USD)

      expect_capture()

      refute Picsello.Orders.client_paid?(order)

      make_request(conn)

      assert Picsello.Orders.client_paid?(order)
    end

    test "tells WHCC", %{conn: conn, order: order, gallery: gallery} do
      order = add_cart_product(order, ~M[1000]USD)

      "" <> account_id = Picsello.Galleries.account_id(gallery)

      Mox.expect(
        Picsello.MockWHCCClient,
        :confirm_order,
        fn ^account_id, "whcc-order-created-id" ->
          {:ok, "whcc-order-confirmed-id"}
        end
      )

      expect_retrieve(~M[1000]USD)
      expect_capture()

      refute order.placed_at

      make_request(conn)

      assert %{placed_at: %DateTime{}} = Repo.reload!(order)
    end

    test "emails the client", %{
      conn: conn,
      order: order,
      organization: %{name: organization_name},
      gallery: %{client_link_hash: gallery_hash}
    } do
      add_cart_product(order, ~M[1000]USD)

      expect_retrieve(~M[1000])
      expect_capture()

      Mox.expect(
        Picsello.MockWHCCClient,
        :confirm_order,
        fn _, _ ->
          {:ok, "whcc-order-confirmed-id"}
        end
      )

      make_request(conn)

      assert_receive {:delivered_email,
                      %{
                        private: %{
                          send_grid_template: %{
                            dynamic_template_data: email_variables
                          }
                        },
                        to: [{nil, "client@example.com"}]
                      }}

      order_number = Order.number(order)

      assert %{
               "client_name" => nil,
               "gallery_url" => gallery_url,
               "logo_url" => nil,
               "order_address" => nil,
               "order_date" => date,
               "order_items" => [
                 %{
                   item_is_digital: false,
                   item_name: "20×30 polo",
                   item_price: ~M[2000]USD,
                   item_quantity: 1
                 }
               ],
               "order_number" => ^order_number,
               "order_shipping" => ~M[0]USD,
               "order_subtotal" => ~M[2000]USD,
               "order_total" => ~M[2000]USD,
               "order_url" => order_url,
               "subject" => subject
             } = email_variables

      assert Regex.match?(~r|\d\d?/\d\d?/\d\d?|, date)

      assert String.starts_with?(subject, organization_name)
      assert String.ends_with?(subject, to_string(order_number))

      assert ["/", "gallery", ^gallery_hash] =
               gallery_url |> URI.parse() |> Map.get(:path) |> Path.split()

      order_number = to_string(order_number)

      assert ["/", "gallery", ^gallery_hash, "orders", ^order_number] =
               order_url |> URI.parse() |> Map.get(:path) |> Path.split()

      assert Jason.decode!(Jason.encode!(email_variables))
    end

    test "logs error if WHCC breaks", %{conn: conn, order: order} do
      add_cart_product(order, ~M[1000]USD)

      Mox.expect(Picsello.MockWHCCClient, :confirm_order, fn _, _ -> {:error, "oops"} end)
      Mox.expect(Picsello.MockPayments, :cancel_payment_intent, fn _, _ -> {:ok, nil} end)

      expect_retrieve(~M[1000]USD)

      Process.flag(:trap_exit, true)

      assert fn -> make_request(conn) end
             |> capture_log()
             |> String.contains?("{:error, :confirm_order, \"oops\"")
    end
  end

  describe "invoices" do
    def stub_invoice_event(invoice) do
      Mox.stub(Picsello.MockPayments, :construct_event, fn _, _, _ ->
        {:ok,
         %{
           type: "invoice.payment_succeeded",
           data: %{
             object: invoice
           }
         }}
      end)
    end

    def make_app_request(conn) do
      conn
      |> put_req_header("stripe-signature", "love, stripe")
      |> post(Routes.stripe_webhooks_path(conn, :app_webhooks), %{})
    end

    test "ignores subscription invoices", %{conn: conn} do
      stub_invoice_event(%Stripe.Invoice{
        subscription: "sub_123"
      })

      make_app_request(conn)
    end

    test "handles order invoices", %{conn: conn} do
      Mox.stub(Picsello.MockWHCCClient, :confirm_order, fn _, _ ->
        {:ok, :confirmed}
      end)

      order =
        insert(:order,
          delivery_info: %{email: "client@example.com"},
          whcc_order: build(:whcc_order_created),
          placed_at: DateTime.utc_now()
        )

      invoice =
        insert(:invoice,
          order: order,
          status: :open,
          stripe_id: "invoice-stripe-id"
        )

      stub_invoice_event(build(:stripe_invoice, status: "paid", id: "invoice-stripe-id"))

      make_app_request(conn)

      assert %{status: :paid} = invoice |> Repo.reload()
    end
  end
end
