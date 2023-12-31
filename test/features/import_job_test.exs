defmodule Picsello.ImportJobTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  alias Picsello.{
    Repo,
    Package,
    Job,
    Client,
    PaymentSchedule,
    BookingProposal,
    Organization,
    EmailAutomationNotifierMock
  }

  setup :onboarded
  setup :authenticated

  @client_name "Elizabeth Taylor"
  @client_email "taylor@example.com"

  setup %{user: user} do
    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    stub_stripe_account!()

    EmailAutomationNotifierMock
    |> Mox.expect(:deliver_automation_email_job, 1, fn _, _, _, _, _ ->
      {:ok, {:ok, "Email Sent"}}
    end)

    :ok
  end

  defp fill_in_new_client_form(session, opts \\ []) do
    phone = Keyword.get(opts, :phone, "2015551234")

    session
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Name"), with: @client_name)
    |> fill_in(text_field("Client Email"), with: @client_email)
    |> fill_in(css("input[type=tel]"), with: phone)
    |> scroll_into_view(css("label", text: "Wedding"))
    |> click(css("label", text: "Wedding"))
  end

  defp fill_in_existing_client_form(session, _opts \\ []) do
    session
    |> fill_in(text_field("search_phrase"), with: "tayl")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Wedding"))
  end

  defp fill_in_package_form(session) do
    session
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> find(
      text_field("The amount you’ve charged for your job"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "1000.00"))
    )
    |> find(
      text_field("How much of the creative session fee is for print credits"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$100.00"))
    )
    |> find(
      text_field("The amount you’ve already collected"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$200.00"))
    )
    |> scroll_into_view(testid("remaining-balance"))
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$800.00"))
  end

  defp fill_in_payments_form(session) do
    session
    |> assert_text("Balance to collect: $800.00")
    |> assert_text("Remaining to collect: $800.00")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: "300"))
    |> click(css("#payment-0"))
    |> fill_in(css(".numInput.cur-year"), with: "2030")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("January")))
    |> click(css("[aria-label='January 1, 2030']"))
    |> assert_text("Remaining to collect: $500.00")
    |> find(testid("payment-2"), &fill_in(&1, text_field("Payment amount"), with: "500"))
    |> click(css("#payment-1"))
    |> fill_in(css(".numInput.cur-year"), with: "2030")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("February")))
    |> click(css("[aria-label='February 1, 2030']"))
    |> assert_text("Remaining to collect: $0.00")
  end

  def stub_stripe_account!(charges_enabled \\ true) do
    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: charges_enabled}}
    end)
  end

  def import_job(session) do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> click(button("Finish"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> click(css("div[title='Mary Jane']"))
    |> click(button("Logout"))
    |> assert_path("/")
  end

  feature "user imports job", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> click(button("Finish"))
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(link("Edit"))
    end)
    |> assert_text("Wedding Deluxe")
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
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
    |> scroll_to_bottom()
    |> assert_text("Paid")
    |> assert_text("200.00 USD")
    |> assert_text("Owed")
    |> assert_text("800.00 USD")

    base_price = Money.new(100_000, "USD")
    download_each_price = Money.new(5000, "USD")
    print_credits = Money.new(10_000, "USD")
    collected_price = Money.new(20_000, "USD")

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
             download_count: 0,
             buy_all: nil,
             print_credits: ^print_credits,
             download_each_price: ^download_each_price,
             collected_price: ^collected_price
           } = job.package

    assert %Client{
             name: "Elizabeth Taylor",
             email: "taylor@example.com",
             phone: "+12015551234"
           } = job.client

    payment1_price = Money.new(30_000, "USD")
    payment2_price = Money.new(50_000, "USD")

    assert [
             %PaymentSchedule{
               due_at: ~U[2030-01-01 00:00:00Z],
               price: ^payment1_price,
               description: "Payment 1"
             },
             # please don't make it 2030-01-02
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
      name: "Elizabeth Taylor",
      phone: nil,
      email: @client_email
    )

    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_existing_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> click(button("Finish"))
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(link("Edit"))
    end)
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
             phone: nil
           } = job.client
  end

  feature "user imports job with existing client and without phone", %{
    session: session,
    user: user
  } do
    client =
      insert(:client,
        user: user,
        name: "Elizabeth Taylor",
        phone: nil,
        email: @client_email
      )

    insert(:lead, client: client)

    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> fill_in_existing_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> click(button("Finish"))
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(link("Edit"))
    end)
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
    |> assert_text("During your job import, you marked this as an external document")

    job = Repo.last(Job) |> Repo.preload([:client])

    assert %Job{
             type: "wedding"
           } = job

    assert %Client{
             name: "Elizabeth Taylor",
             email: "taylor@example.com",
             phone: nil
           } = job.client
  end

  feature "user imports job with only one payment", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> assert_text("Remaining to collect: $0.00")
    |> find(testid("payment-2"), &click(&1, button("Remove")))
    |> assert_text("Remaining to collect: $500.00")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: "$800"))
    |> assert_text("Remaining to collect: $0.00")
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> click(button("Finish"))
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
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> find(
      text_field("The amount you’ve already collected"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$1000"))
    )
    |> scroll_into_view(testid("remaining-balance"))
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$0.00"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> assert_text("Since your remaining balance is $0.00")
    |> assert_text("Remaining to collect: $0.00")
    |> click(button("Next"))
    |> click(button("Finish"))
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

  feature "user imports job with zero base price", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> fill_in(text_field("The amount you’ve charged for your job"), with: "$0.00")
    |> assert_disabled(text_field("How much of the creative session fee is for print credits"))
    |> assert_disabled(text_field("The amount you’ve already collected"))
    |> scroll_into_view(testid("remaining-balance"))
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$0.00"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> assert_text("Since your remaining balance is $0.00")
    |> assert_text("Remaining to collect: $0.00")
    |> click(button("Next"))
    |> click(button("Finish"))
    |> assert_has(css("#modal-wrapper.hidden", visible: false))
    |> assert_text("Wedding Deluxe")
  end

  feature "user sees validation errors when importing job", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in(text_field("Client Name"), with: " ")
    |> assert_has(css("label", text: "Client Name can't be blank"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in(text_field("Title"), with: " ")
    |> assert_has(css("label", text: "Title can't be blank"))
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: " "))
    |> assert_has(css("label", text: "Payment amount must be greater than 0"))
    |> assert_disabled_submit()
  end

  feature "user navigates back and forth on steps", %{session: session} do
    session
    |> click(button("Jobs"))
    |> click(button("Import a job"))
    |> find(testid("import-job-card"), &click(&1, button("Next")))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Add a new client"))
    |> fill_in_new_client_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> click(button("Go back"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> click(button("Go back"))
    |> assert_text("Import Existing Job: General Details")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> click(button("Next"))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> click(button("Next"))
    |> click(button("Finish"))
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

      {:ok,
       %{
         url: "https://example.com/stripe-checkout",
         payment_intent: "new_intent_id",
         id: "new_session_id"
       }}
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
    |> assert_has(button("View invoice", count: 1))
    |> click(button("View invoice"))
    |> assert_text("Paid")
    |> assert_text("200.00 USD")
    |> assert_text("Owed")
    |> assert_text("800.00 USD")
    |> assert_has(button("Pay online", at: 1))
    |> click(button("Pay online", at: 1))
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
    |> assert_text("Congratulations - your sessions are now booked")

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
    |> assert_disabled(button("Pay online"))
    |> assert_flash(:error, text: "Payment is not enabled yet")
  end
end
