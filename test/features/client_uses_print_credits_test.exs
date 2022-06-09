defmodule Picsello.ClientUsesPrintCreditsTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Cart.Order, Repo}
  import Money.Sigils

  setup do
    Mox.verify_on_exit!()

    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")

    insert(:user,
      organization: organization,
      stripe_customer_id: "photographer-stripe-customer-id",
      email: "photographer@example.com"
    )

    package =
      insert(:package,
        organization: organization,
        print_credits: ~M[10000]USD,
        download_each_price: ~M[5500]USD
      )

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          )
      )

    insert(:watermark, gallery: gallery)

    category =
      insert(:category,
        default_markup: Decimal.new("1.1"),
        shipping_upcharge: Decimal.new(0),
        shipping_base_charge: ~M[500]USD
      )

    product = insert(:product, category: category)

    insert(:gallery_product,
      category: category,
      preview_photo: insert(:photo, gallery: gallery),
      gallery: gallery
    )

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    [
      gallery: gallery,
      organization: organization,
      product: product,
      package: package
    ]
  end

  def click_photo(session, position) do
    session |> click(css("#muuri-grid .muuri-item-shown:nth-child(#{position}) *[id^='img']"))
  end

  def fill_in_shipping(session),
    do:
      session
      |> fill_in(text_field("Email address"), with: "client@example.com")
      |> fill_in(text_field("Name"), with: "brian")
      |> fill_in(text_field("Shipping address"), with: "123 w main st")
      |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
      |> click(option("OK"))
      |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
      |> wait_for_enabled_submit_button()

  def stub_whcc(%{
        whcc_total: total,
        whcc_unit_base_price: unit_base_price,
        product: %{attribute_categories: attribute_categories, whcc_id: whcc_product_id}
      }) do
    [size] =
      for %{"_id" => "size", "attributes" => [%{"id" => id} | _]} <- attribute_categories,
          do: id

    test_pid = self()

    Picsello.MockWHCCClient
    |> Mox.stub(:editor, fn args ->
      assert %{
               "redirects" => %{"complete" => %{"url" => complete_url}}
             } = args

      url =
        complete_url
        |> URI.parse()
        |> Map.update!(:query, &String.replace(&1, "%EDITOR_ID%", "editor-id"))
        |> URI.to_string()

      %Picsello.WHCC.CreatedEditor{url: url}
    end)
    |> Mox.stub(:editor_details, fn _wat, "editor-id" ->
      build(:whcc_editor_details,
        product_id: whcc_product_id,
        selections: %{"size" => size, "quantity" => 1},
        editor_id: "editor-id"
      )
    end)
    |> Mox.stub(:editors_export, fn _account_id, [%{id: "editor-id"}], _opts ->
      build(:whcc_editor_export, unit_base_price: unit_base_price, order_sequence_number: 1)
    end)
    |> Mox.stub(:create_order, fn _account_id, _export ->
      {:ok,
       build(:whcc_order_created,
         orders: build_list(1, :whcc_order_created_order, total: total, sequence_number: 1)
       )}
    end)
    |> Mox.stub(:confirm_order, fn _account_id, order ->
      send(test_pid, {:order_confirmed, order})
      {:ok, :confirmed}
    end)

    :ok
  end

  def trigger_stripe_webhook(session, type, object) do
    Mox.expect(Picsello.MockPayments, :construct_event, fn _body, _str, _sig ->
      {:ok, %Stripe.Event{type: type, data: %{object: object}}}
    end)

    post(
      session,
      PicselloWeb.Router.Helpers.stripe_webhooks_path(PicselloWeb.Endpoint, :app_webhooks),
      Jason.encode!(%{}),
      [{"stripe-signature", "love, stripe"}]
    )
  end

  def expect_create_invoice(%{stripe_invoice: %{amount_due: amount} = invoice}) do
    Picsello.MockPayments
    |> Mox.expect(:create_invoice, fn %{
                                        auto_advance: true,
                                        customer: "photographer-stripe-customer-id"
                                      },
                                      _opts ->
      {:ok, invoice}
    end)
    |> Mox.expect(:create_invoice_item, fn %{
                                             amount: ^amount,
                                             customer: "photographer-stripe-customer-id"
                                           },
                                           _opts ->
      {:ok, %Stripe.Invoiceitem{invoice: invoice}}
    end)

    :ok
  end

  def expect_finalize_invoice(%{stripe_invoice: invoice}) do
    Mox.expect(Picsello.MockPayments, :finalize_invoice, fn %{id: "stripe-invoice-id"},
                                                            %{auto_advance: true},
                                                            _opts ->
      {:ok, %{invoice | status: :open}}
    end)

    :ok
  end

  def expect_stripe_checkout(%{
        stripe_checkout: %{
          application_fee_amount: %{amount: application_fee_amount},
          amount: %{amount: amount_cents}
        }
      }) do
    test_pid = self()

    intent =
      build(:stripe_payment_intent,
        application_fee_amount: application_fee_amount,
        amount: amount_cents
      )

    Picsello.MockPayments
    |> Mox.expect(:create_session, fn params, _ ->
      assert %{
               success_url: success_url,
               payment_intent_data: %{
                 application_fee_amount: ^application_fee_amount
               }
             } = params

      {:ok,
       build(:stripe_session,
         url: success_url,
         payment_intent: intent
       )}
    end)
    |> Mox.stub(:retrieve_session, fn session_id, _opts ->
      order_number = Order |> Repo.one!() |> Order.number()

      {:ok,
       build(:stripe_session,
         id: session_id,
         payment_status: "unpaid",
         payment_intent: intent.id,
         client_reference_id: "order_number_#{order_number}"
       )}
    end)
    |> Mox.stub(
      :retrieve_payment_intent,
      fn payment_intent_id, _opts ->
        {:ok,
         %{
           intent
           | id: payment_intent_id,
             status: "requires_capture",
             amount_capturable: amount_cents,
             amount: amount_cents
         }}
      end
    )
    |> Mox.stub(
      :capture_payment_intent,
      fn payment_intent_id, _opts ->
        send(test_pid, {:capture_payment_intent, payment_intent_id})

        {:ok,
         %{
           intent
           | id: payment_intent_id,
             status: "succeeded",
             amount_capturable: amount_cents,
             amount: amount_cents
         }}
      end
    )

    :ok
  end

  setup :authenticated_gallery_client

  # Order total: $100
  # printing cost: $50
  # print credit: $100
  # client charge: $0
  # invoice photographer $50
  # remaining print credits: $0

  describe "all print credits - none left over" do
    setup do
      [
        stripe_invoice:
          build(:stripe_invoice,
            id: "stripe-invoice-id",
            description: "stripe invoice!",
            amount_due: 5000,
            amount_remaining: 5000,
            status: :draft
          ),
        whcc_unit_base_price: ~M[4500]USD,
        whcc_total: ~M[5000]USD
      ]
    end

    setup [:expect_create_invoice, :expect_finalize_invoice, :stub_whcc]

    feature "only charges photographer", %{
      session: session,
      stripe_invoice: invoice
    } do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$100.00"))
      |> scroll_to_bottom()
      |> click_photo(1)
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart Review")
      |> assert_has(definition("Products (1)", text: "$100.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> assert_has(definition("Total", text: "$0.00"))
      |> click(button("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out"))

      assert [%{errors: []}] = run_jobs()

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$0.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> click(link("Home"))
      |> refute_has(definition("Print Credit"))

      refute_receive({:order_confirmed, _order})

      trigger_stripe_webhook(session, "invoice.payment_succeeded", %{
        invoice
        | amount_paid: 5000,
          amount_due: 0,
          amount_remaining: 0,
          status: :paid
      })

      assert_receive({:order_confirmed, _order})
    end
  end

  # Order total: $50
  # printing cost: $20
  # print credit: $100
  # client charge: $0
  # photographer invoice: $20
  # remaining print credits: $50

  describe "all print credits - some left over" do
    setup do
      [
        stripe_invoice:
          build(:stripe_invoice,
            id: "stripe-invoice-id",
            description: "stripe invoice!",
            amount_due: 5000,
            amount_remaining: 5000,
            status: :draft
          ),
        whcc_unit_base_price: ~M[2000]USD,
        whcc_total: ~M[5000]USD
      ]
    end

    setup [:expect_create_invoice, :expect_finalize_invoice, :stub_whcc]

    feature("only charges photographer", %{session: session, stripe_invoice: invoice}) do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$100.00"))
      |> scroll_to_bottom()
      |> click_photo(1)
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart Review")
      |> assert_has(definition("Products (1)", text: "50.00"))
      |> assert_has(definition("Print credits used", text: "$50.00"))
      |> assert_has(definition("Total", text: "$0.00"))
      |> click(button("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out"))

      assert [%{errors: []}] = run_jobs()

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$0.00"))
      |> assert_has(definition("Print credits used", text: "$50.00"))
      |> click(link("Home"))
      |> assert_has(definition("Print Credit", text: "$50.00"))

      refute_receive({:order_confirmed, _order})

      trigger_stripe_webhook(session, "invoice.payment_succeeded", %{
        invoice
        | amount_paid: 2000,
          amount_due: 0,
          amount_remaining: 0,
          status: :paid
      })

      assert_receive({:order_confirmed, _order})
    end
  end

  # Order total: $155
  # printing cost: $50
  # print credit: $100
  # client charge: $55
  # application fee: $50
  # invoice photographer: $0
  # remaining print credits: $0

  describe "client charge covers print cost" do
    setup do
      [
        whcc_unit_base_price: ~M[4500]USD,
        whcc_total: ~M[5000]USD,
        stripe_checkout: %{application_fee_amount: ~M[5000]USD, amount: ~M[5500]USD}
      ]
    end

    setup [:stub_whcc, :expect_stripe_checkout]

    feature("only charges client", %{session: session}) do
      session
      |> click(link("View Gallery"))
      |> scroll_to_bottom()
      |> click_photo(1)
      |> click(button("Add to cart"))
      |> click(link("Home"))
      |> assert_has(definition("Print Credit", text: "$100.00"))
      |> scroll_to_bottom()
      |> click_photo(1)
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart Review")
      |> assert_has(definition("Products (1)", text: "100.00"))
      |> assert_has(definition("Digital downloads (1)", text: "55.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> assert_has(definition("Total", text: "$55.00"))
      |> click(button("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$55.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> click(link("Home"))
      |> refute_has(definition("Print Credit"))

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      assert_receive({:order_confirmed, _order})
    end
  end

  # Order total: $120
  # printing cost: $50
  # print credit: $100
  # client charge: $20
  # application fee: $20
  # invoice photographer: $30
  # remaining print credits: $0

  describe "client charge partially covers print cost" do
    setup do
      stripe_invoice =
        build(:stripe_invoice,
          id: "stripe-invoice-id",
          description: "stripe invoice!",
          amount_due: 3000,
          amount_remaining: 3000,
          status: "draft"
        )

      Mox.expect(Picsello.MockPayments, :finalize_invoice, fn "stripe-invoice-id",
                                                              _params,
                                                              _opts ->
        {:ok, %{stripe_invoice | status: "open"}}
      end)

      [
        stripe_invoice: stripe_invoice,
        whcc_unit_base_price: ~M[5300]USD,
        whcc_total: ~M[5000]USD,
        stripe_checkout: %{application_fee_amount: ~M[2000]USD, amount: ~M[2000]USD}
      ]
    end

    setup [:stub_whcc, :expect_create_invoice, :expect_stripe_checkout]

    feature("charges both client and photographer", %{session: session, stripe_invoice: invoice}) do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$100.00"))
      |> scroll_to_bottom()
      |> click_photo(1)
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart Review")
      |> assert_has(definition("Products (1)", text: "120.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> assert_has(definition("Total", text: "$20.00"))
      |> click(button("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "20.00"))
      |> assert_has(definition("Print credits used", text: "$100.00"))
      |> click(link("Home"))
      |> refute_has(definition("Print Credit"))

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})
      refute_receive({:order_confirmed, _order})
      refute_receive({:capture_payment_intent, _intent_id})

      trigger_stripe_webhook(session, "invoice.payment_succeeded", %{
        invoice
        | amount_paid: 2000,
          amount_due: 0,
          amount_remaining: 0,
          status: :paid
      })

      assert_receive({:order_confirmed, _order})
      assert_receive({:capture_payment_intent, _intent_id})
    end
  end
end
