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
    |> onboard!()

    package =
      insert(:package,
        organization: organization,
        print_credits: ~M[500000]USD,
        download_each_price: ~M[5500]USD
      )

    gallery =
      insert(:gallery,
        use_global: %{watermark: true, expiration: true, digital: true, products: true},
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
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 3})

    insert(:gallery_product,
      category: category,
      preview_photo: insert(:photo, gallery: gallery),
      gallery: gallery
    )

    global_gallery_product =
      insert(:global_gallery_product,
        category: category,
        organization: organization,
        markup: 100
      )

    if category.whcc_id == "h3GrtaTf5ipFicdrJ" do
      product = insert(:product, category: category)

      insert(:global_gallery_print_product,
        product: product,
        global_settings_gallery_product: global_gallery_product
      )
    end

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, & &1)
    |> Mox.stub(:get, fn _ -> {:error, nil} end)

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "photographer-stripe-customer-id", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [
      gallery: gallery,
      organization: organization,
      product: product,
      package: package,
      photo_ids: photo_ids
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
      build(:whcc_editor_export,
        unit_base_price: unit_base_price,
        order_sequence_number: 1,
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

  def trigger_stripe_webhook(session, category, type, object) do
    Mox.expect(Picsello.MockPayments, :construct_event, fn _body, _str, _sig ->
      {:ok, %Stripe.Event{type: type, data: %{object: object}}}
    end)

    post(
      session,
      PicselloWeb.Router.Helpers.stripe_webhooks_path(
        PicselloWeb.Endpoint,
        :"#{category}_webhooks"
      ),
      Jason.encode!(%{}),
      [{"stripe-signature", "love, stripe"}]
    )
  end

  def expect_create_invoice(%{stripe_invoice: %{amount_due: amount} = invoice}) do
    IO.inspect(amount)

    Picsello.MockPayments
    |> Mox.expect(:create_invoice, fn %{
                                        auto_advance: true,
                                        customer: "photographer-stripe-customer-id"
                                      },
                                      _opts ->
      {:ok, invoice}
    end)
    |> Mox.expect(:create_invoice_item, fn %{
                                             amount: amount,
                                             customer: "photographer-stripe-customer-id"
                                           },
                                           _opts ->
      IO.inspect(amount)
      {:ok, %Stripe.Invoiceitem{invoice: invoice}}
    end)

    :ok
  end

  def expect_finalize_invoice(%{stripe_invoice: invoice}) do
    Mox.expect(Picsello.MockPayments, :finalize_invoice, fn "stripe-invoice-id",
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
      IO.inspect(params)

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

    [stripe_payment_intent: intent]
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
            amount_due: 4510,
            amount_remaining: 5000,
            status: :draft
          ),
        whcc_unit_base_price: ~M[4200]USD,
        whcc_total: ~M[5000]USD,
        stripe_checkout: %{application_fee_amount: ~M[490]USD, amount: ~M[5500]USD}
      ]
    end

    setup [:expect_create_invoice, :expect_finalize_invoice, :stub_whcc, :expect_stripe_checkout]

    feature "only charges photographer", %{
      session: session,
      stripe_invoice: invoice,
      photo_ids: photo_ids
    } do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$5,000.00"))
      |> scroll_to_bottom()
      |> click(css("#img-#{List.first(photo_ids)}"))
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart & Shipping Review")
      |> assert_has(definition("Products (1)", text: "$4,242.00"))
      |> assert_has(definition("Print credits used", text: "$4,242.00"))
      |> assert_has(definition("Total", text: "$4.90"))
      |> click(link("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out"))

      assert [%{errors: []}] = run_jobs()

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$4.90"))
      |> assert_has(definition("Print credits used", text: "$4,242.00"))
      |> click(link("Home"))
      |> assert_has(definition("Print Credit", text: "$758.00"))

      refute_receive({:order_confirmed, _order})

      trigger_stripe_webhook(session, :app, "invoice.payment_succeeded", %{
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
            amount_due: 4510,
            amount_remaining: 5000,
            status: :draft
          ),
        whcc_unit_base_price: ~M[2000]USD,
        whcc_total: ~M[5000]USD,
        stripe_checkout: %{application_fee_amount: ~M[1095]USD, amount: ~M[5500]USD}
      ]
    end

    setup [:expect_create_invoice, :expect_finalize_invoice, :stub_whcc, :expect_stripe_checkout]

    feature("only charges photographer", %{
      session: session,
      stripe_invoice: invoice,
      photo_ids: photo_ids
    }) do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$5,000.00"))
      |> scroll_to_bottom()
      |> click(css("#img-#{List.first(photo_ids)}"))
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart & Shipping Review")
      |> assert_has(definition("Products (1)", text: "2,020.00"))
      |> assert_has(definition("Print credits used", text: "$2,020.00"))
      |> assert_has(definition("Total", text: "$10.95"))
      |> click(link("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out"))

      assert [%{errors: []}] = run_jobs()

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$10.95"))
      |> assert_has(definition("Print credits used", text: "$2,020.00"))
      |> click(link("Home"))
      |> assert_has(definition("Print Credit", text: "$2,980.00"))

      refute_receive({:order_confirmed, _order})

      trigger_stripe_webhook(session, :app, "invoice.payment_succeeded", %{
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
        stripe_checkout: %{application_fee_amount: ~M[6095]USD, amount: ~M[5500]USD}
      ]
    end

    setup [:stub_whcc, :expect_stripe_checkout]

    feature("only charges client", %{session: session, photo_ids: photo_ids}) do
      session
      |> click(link("View Gallery"))
      |> scroll_to_bottom()
      |> click(css("#img-#{List.first(photo_ids)}"))
      |> click(button("Add to cart"))
      |> click(link("Home"))
      |> assert_has(definition("Print Credit", text: "$5,000.00"))
      |> scroll_to_bottom()
      |> click(css("#img-#{List.first(photo_ids)}"))
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart & Shipping Review")
      |> assert_has(definition("Products (1)", text: "4,545.00"))
      |> assert_has(definition("Digital downloads (1)", text: "55.00"))
      |> assert_has(definition("Print credits used", text: "$4,545.00"))
      |> assert_has(definition("Total", text: "$65.95"))
      |> click(link("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      session
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$65.95"))
      |> assert_has(definition("Print credits used", text: "$4,545.00"))
      |> click(link("Home"))

      # |> refute_has(definition("Print Credit"))

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
          amount_due: 2820,
          amount_remaining: 3000,
          status: "draft"
        )

      [
        stripe_invoice: stripe_invoice,
        whcc_unit_base_price: ~M[5300]USD,
        whcc_total: ~M[5000]USD,
        stripe_checkout: %{application_fee_amount: ~M[6095]USD, amount: ~M[2000]USD}
      ]
    end

    setup [:stub_whcc, :expect_stripe_checkout]

    def place_order(session, photo_ids) do
      session
      |> click(link("View Gallery"))
      |> assert_has(definition("Print Credit", text: "$5,000.00"))
      |> scroll_to_bottom()
      |> click(css("#img-#{List.first(photo_ids)}"))
      |> click(button("Select"))
      |> click(button("Customize & buy"))
      |> assert_text("Cart & Shipping Review")
      |> assert_has(definition("Products (1)", text: "5,353.00"))
      |> assert_has(definition("Print credits used", text: "$5,000.00"))
      |> assert_has(definition("Total", text: "$363.95"))
      |> click(link("Continue"))
      |> fill_in_shipping()
      |> click(button("Check out with Stripe"))

      assert [%{errors: []}] = run_jobs()

      session
    end

    feature("charges both client and photographer", %{
      session: session,
      photo_ids: photo_ids
    }) do
      session
      |> place_order(photo_ids)
      |> sleep(500)
      |> assert_url_contains("orders")
      |> assert_text("Order details")
      |> assert_has(definition("Total", text: "$363.95"))
      |> assert_has(definition("Print credits used", text: "$5,000.00"))
      |> click(link("Home"))
      |> refute_has(definition("Print Credit"))

      assert_receive({:delivered_email, %{to: [{_, "client@example.com"}]}})
      assert_receive({:delivered_email, %{to: [{_, "photographer@example.com"}]}})

      assert_receive({:order_confirmed, _order})
      assert_receive({:capture_payment_intent, _intent_id})
    end

    feature("cancels if client hold expires", %{
      session: session,
      stripe_payment_intent: intent,
      photo_ids: photo_ids
    }) do
      session
      |> place_order(photo_ids)
      |> trigger_stripe_webhook(:connect, "payment_intent.canceled", %{
        intent
        | status: "canceled"
      })
      |> click(link("My orders"))
      |> assert_text("Order Canceled")
      |> click(link("View details"))
      |> assert_text("Order Canceled")

      assert_receive(
        {:delivered_email, %{subject: "Order canceled", to: [{_, "photographer@example.com"}]}}
      )

      assert_receive(
        {:delivered_email, %{subject: "Order canceled", to: [{_, "client@example.com"}]}}
      )
    end
  end
end
