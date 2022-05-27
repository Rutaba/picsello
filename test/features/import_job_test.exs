defmodule Picsello.ImportJobTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package, Job, Client, PaymentSchedule, BookingProposal, Organization}

  setup :onboarded
  setup :authenticated

  @client_name "Elizabeth Taylor"
  @client_email "taylor@example.com"

  setup %{user: user} do
    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    stub_stripe_account!()

    :ok
  end

  def fill_in_client_form(session) do
    session
    |> fill_in(text_field("Client Name"), with: @client_name)
    |> fill_in(text_field("Client Email"), with: @client_email)
    |> fill_in(text_field("Client Phone"), with: "(210) 111-1234")
    |> click(css("label", text: "Wedding"))
  end

  def fill_in_package_form(session) do
    session
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> fill_in(text_field("The amount you’ve charged for your job"), with: "$1000")
    |> fill_in(text_field("How much of the creative session fee is for print credits"),
      with: "$100"
    )
    |> fill_in(text_field("The amount you’ve already collected"), with: "$200")
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$800.00"))
    |> scroll_into_view(css("#download_is_enabled_false"))
    |> click(checkbox("Set my own download price"))
    |> find(
      text_field("download_each_price"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> click(checkbox("download_includes_credits"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "2"))
    )
    |> click(checkbox("package_pricing_is_buy_all"))
    |> find(
      text_field("package[buy_all]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$10"))
    )
  end

  def fill_in_payments_form(session) do
    session
    |> assert_text("Balance to collect: $800.00")
    |> assert_text("Remaining to collect: $800.00")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: "$300"))
    |> find(testid("payment-1"), &fill_in(&1, text_field("Due"), with: "01/01/2030"))
    |> assert_text("Remaining to collect: $500.00")
    |> find(testid("payment-2"), &fill_in(&1, text_field("Payment amount"), with: "$500"))
    |> find(testid("payment-2"), &fill_in(&1, text_field("Due"), with: "02/01/2030"))
    |> assert_text("Remaining to collect: $0.00")
  end

  def stub_stripe_account!(charges_enabled \\ true) do
    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: charges_enabled}}
    end)
  end

  def import_job(session) do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> click(css("div[title='Mary Jane']"))
    |> click(button("Logout"))
    |> assert_path("/")
  end

  feature "user imports job", %{session: session} do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_has(testid("shoot-card", count: 2, at: 0, text: "Missing information"))
    |> assert_has(testid("shoot-card", count: 2, at: 1, text: "Missing information"))
    |> find(
      testid("contract"),
      &assert_text(&1, "During your job import, you marked this as an external document")
    )
    |> find(
      testid("questionnaire"),
      &assert_text(&1, "During your job import, you marked this as an external document")
    )
    |> click(button("View invoice"))
    |> assert_has(definition("Previously collected", text: "$200.00"))
    |> assert_has(definition("Payment 1 due on Jan 01, 2030", text: "$300.00"))
    |> assert_has(definition("Payment 2 due on Feb 01, 2030", text: "$500.00"))

    base_price = Money.new(100_000)
    download_each_price = Money.new(200)
    buy_all = Money.new(1000)
    print_credits = Money.new(10_000)
    collected_price = Money.new(20_000)

    job =
      Repo.one(Job) |> Repo.preload([:package, :payment_schedules, :client, :booking_proposals])

    assert %Job{
             type: "wedding"
           } = job

    assert %Package{
             name: "Wedding Deluxe",
             shoot_count: 2,
             turnaround_weeks: 2,
             description: nil,
             base_price: ^base_price,
             download_count: 2,
             buy_all: ^buy_all,
             print_credits: ^print_credits,
             download_each_price: ^download_each_price,
             collected_price: ^collected_price
           } = job.package

    assert %Client{
             name: "Elizabeth Taylor",
             email: "taylor@example.com",
             phone: "(210) 111-1234"
           } = job.client

    payment1_price = Money.new(30_000)
    payment2_price = Money.new(50_000)

    assert [
             %PaymentSchedule{
               due_at: ~U[2030-01-01 00:00:00Z],
               price: ^payment1_price,
               description: "Payment 1"
             },
             %PaymentSchedule{
               due_at: ~U[2030-02-01 00:00:00Z],
               price: ^payment2_price,
               description: "Payment 2"
             }
           ] = job.payment_schedules

    assert [%BookingProposal{}] = job.booking_proposals
  end

  feature "user imports job with existing client", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: nil,
      phone: nil,
      email: @client_email
    )

    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_text("During your job import, you marked this as an external document")

    job = Repo.one(Job) |> Repo.preload([:client])

    assert %Job{
             type: "wedding"
           } = job

    assert %Client{
             name: "Elizabeth Taylor",
             email: "taylor@example.com",
             phone: "(210) 111-1234"
           } = job.client
  end

  feature "user imports job with only one payment", %{session: session} do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> assert_text("Remaining to collect: $0.00")
    |> find(testid("payment-2"), &click(&1, button("Remove")))
    |> assert_text("Remaining to collect: $500.00")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: "$800"))
    |> assert_text("Remaining to collect: $0.00")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    job = Repo.one(Job) |> Repo.preload([:payment_schedules])

    payment1_price = Money.new(80_000)

    assert [
             %PaymentSchedule{
               due_at: ~U[2030-01-01 00:00:00Z],
               price: ^payment1_price,
               description: "Payment 1"
             }
           ] = job.payment_schedules
  end

  feature "user imports job without payments", %{session: session} do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> fill_in(text_field("The amount you’ve already collected"), with: "$1000")
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$0.00"))
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")

    base_price = Money.new(100_000)

    job = Repo.one(Job) |> Repo.preload([:package, :payment_schedules])

    assert %Package{
             base_price: ^base_price,
             collected_price: ^base_price
           } = job.package

    assert [] = job.payment_schedules
  end

  feature "user sees validation errors when importing job", %{session: session} do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in(text_field("Client Name"), with: " ")
    |> assert_has(css("label", text: "Client Name can't be blank"))
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in(text_field("Title"), with: " ")
    |> assert_has(css("label", text: "Title can't be blank"))
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: " "))
    |> assert_has(css("label", text: "Payment amount is invalid"))
    |> assert_disabled_submit()
  end

  feature "user navigates back and forth on steps", %{session: session} do
    session
    |> click(testid("jobs-card"))
    |> click(link("Import existing job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Go back"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> click(button("Go back"))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> click(button("Save"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
  end

  feature "client pays invoice from imported job", %{session: session} do
    import_job(session)

    %{booking_proposals: [proposal], payment_schedules: [%{id: payment_id} = payment | _]} =
      Repo.one(Job) |> Repo.preload([:booking_proposals, :payment_schedules])

    url = BookingProposal.url(proposal.id)

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_customer, fn %{email: @client_email, name: @client_name}, _ ->
      {:ok, %Stripe.Customer{id: "stripe-customer-id"}}
    end)
    |> Mox.stub(:create_session, fn params, opts ->
      send(
        test_pid,
        {:checkout_linked, opts |> Enum.into(params)}
      )

      {:ok, "https://example.com/stripe-checkout"}
    end)
    |> Mox.expect(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
      {:ok,
       %Stripe.Session{
         client_reference_id: "proposal_#{proposal.id}",
         metadata: %{"paying_for" => payment_id}
       }}
    end)

    session
    |> visit(url)
    |> assert_has(button("Proposal", count: 0))
    |> assert_has(button("Contract", count: 0))
    |> assert_has(button("Questionnaire", count: 0))
    |> assert_has(button("Invoice", count: 1))
    |> click(button("Invoice"))
    |> assert_has(definition("Previously collected", text: "$200.00"))
    |> assert_has(definition("Payment 1 due on Jan 01, 2030", text: "$300.00"))
    |> assert_has(definition("Payment 2 due on Feb 01, 2030", text: "$500.00"))
    |> click(button("Pay Invoice"))
    |> assert_url_contains("stripe-checkout")

    assert_receive {:checkout_linked,
                    %{
                      success_url: stripe_success_url,
                      metadata: %{"paying_for" => ^payment_id},
                      automatic_tax: %{enabled: true},
                      line_items: [
                        %{
                          price_data: %{
                            product_data: %{
                              name: "Elizabeth Taylor Wedding Payment 1",
                              tax_code: "txcd_20030000"
                            },
                            unit_amount: 30_000,
                            tax_behavior: "exclusive"
                          }
                        }
                      ]
                    }}

    session
    |> visit(stripe_success_url)
    |> assert_text("Thank you! Your sessions are now booked")

    %{paid_at: time} = payment |> Repo.reload!()
    refute is_nil(time)
  end

  feature "invoice is disabled when stripe account is not enabled", %{session: session} do
    import_job(session)
    %{booking_proposals: [proposal]} = Repo.one(Job) |> Repo.preload([:booking_proposals])
    url = BookingProposal.url(proposal.id)

    stub_stripe_account!(false)

    session
    |> visit(url)
    |> assert_disabled(button("Invoice"))
    |> assert_flash(:error, text: "Payment is not enabled yet")
  end
end
