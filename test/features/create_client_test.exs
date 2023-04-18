defmodule Picsello.CreateClientTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{ClientMessage, Galleries.Gallery, Repo, Client, Job, PaymentSchedule, Package}

  setup :onboarded
  setup :authenticated

  @valid_client_params %{
    client_name: "John Snow",
    client_email: "johnsnow@picsello.com"
  }

  @package_name "Event Premium"
  @base_price "$10"

  feature "add-client button renders the add-client form", %{session: session} do
    session
    |> open_add_client_popup()
    |> assert_general_fields()
    |> assert_has(button("Save"))
  end

  feature "save-button adds a new client", %{session: session} do
    session
    |> open_add_client_popup()
    |> fill_client_form()
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_text(@valid_client_params[:client_name])
    |> assert_text(@valid_client_params[:client_email])

    assert Repo.all(Client) |> Enum.count() == 1
  end

  feature "pre-picsello checkbox click renders job-import form", %{session: session} do
    session
    |> open_add_client_popup()
    |> fill_client_form()
    |> click(css(".checkbox"))
    |> within_modal(fn modal ->
      modal
      |> scroll_to_bottom()
      |> assert_general_fields()
      |> assert_has(button("Next"))
      |> assert_stepwise_changes()
    end)
  end

  feature "click prepicsello-checkbox and finish the steps to import a new job", %{
    session: session
  } do
    session
    |> simulate_prepicsello_click_scenario()
    |> sleep(300)

    assert Repo.all(Client) |> Enum.count() == 1
    assert Repo.all(Job) |> Enum.count() == 1
    assert Repo.all(Package) |> Enum.count() == 1
    assert Repo.all(PaymentSchedule) |> Enum.count() == 2
  end

  feature "following the prepicsello click scenario, renders the clients contact-details page", %{
    session: session
  } do
    session
    |> simulate_prepicsello_click_scenario()

    client = Repo.one(Client)

    session
    |> assert_text("All Clients")
    |> assert_text("#{client.name}")
    |> assert_text("Client: #{client.name}")
    |> assert_has(link("Contact Details"))
    |> assert_has(link("Job Details"))
    |> assert_has(link("Order History"))
    |> assert_text("Job Details")
    |> assert_text("Actions")

    job = Repo.one(Job)
    client = Repo.one(Client)
    assert Repo.all(Gallery) |> Enum.count() == 0

    session
    |> click(link("Contact Details"))
    |> assert_text("Details")
    |> assert_text("Private notes")
    |> click(link("Job Details"))
    |> assert_text("Job Details")
    |> assert_has(testid("client-job-#{job.id}"))
    |> click(css("a", text: "Go to Gallery"))
    |> assert_url_contains("/galleries")

    assert Repo.all(Gallery) |> Enum.count() == 1

    session
    |> visit("/clients/#{client.id}/job-history")
    |> click(css("a", text: "Go to Gallery"))
    |> assert_url_contains("/galleries")
    |> visit("/clients/#{client.id}/job-history")
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(link("Edit"))
    end)
    |> assert_url_contains("/jobs/#{job.id}")
    |> visit("/clients/#{client.id}/job-history")
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(css(".envelope"))
    end)
    |> assert_text("Send email")
    |> fill_in(css("#client_message_subject"), with: "Test subject")
    |> fill_in(css(".ql-editor"), with: "Test message")
    |> wait_for_enabled_submit_button()
    |> click(button("Send"))
    |> assert_text("Yay! Your email has been successfully sent")
    |> click(button("Close"))
    |> visit("/clients/#{client.id}/job-history")
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(css(".envelope"))
    end)
    |> click(button("Cancel"))

    assert Repo.all(ClientMessage) |> Enum.count() == 1

    session
    |> visit("/clients/#{client.id}/job-history")
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(css(".trash"))
    end)
    |> assert_text("Are you sure you want to archive this lead?")
    |> click(button("No! Get me out of here"))
    |> visit("/clients/#{client.id}/job-history")
    |> find(css("[data-testid='client-jobs'] > div:first-child"), fn row ->
      row
      |> click(css(".action"))
      |> click(css(".trash"))
    end)
    |> click(css("button", text: "Yes, archive the lead"))
  end

  feature "order-details anchor click, renders the order-details for client", %{session: session} do
    session
    |> simulate_prepicsello_click_scenario()
    |> click(link("Order History"))
    |> assert_text("Waiting for orders from this client!")
  end

  defp simulate_prepicsello_click_scenario(session) do
    session
    |> open_add_client_popup()
    |> fill_client_form()
    |> click(css("#pre-picsello-check"))
    |> within_modal(fn modal ->
      modal
      |> scroll_to_bottom()
      |> force_simulate_click(css(".checkbox-event"))
      |> wait_for_enabled_submit_button()
      |> click(button("Next"))
      |> assert_package_and_payment_fields()
      |> fill_package_form()
      |> wait_for_enabled_submit_button()
      |> click(button("Next"))
      |> assert_invoice_fields()
      |> fill_invoice_form(session)
      |> wait_for_enabled_submit_button()
      |> click(button("Next"))
      |> click(button("Finish"))
    end)
    |> assert_url_contains("clients")
  end

  defp open_add_client_popup(session) do
    session
    |> set_cookie("show_welcome_modal", "")
    |> visit("/home")
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Add client", count: 2, at: 1))
  end

  defp assert_general_fields(session) do
    session
    |> assert_text("Add Client: General Details")
    |> assert_has(css("#client_name"))
    |> assert_has(css("#client_email"))
    |> assert_has(css("#client_phone"))
    |> assert_has(css("#client_address"))
    |> assert_has(css("#client_notes"))
    |> assert_has(css("#clear-notes"))
    |> assert_text("Pre-Picsello Client")
    |> assert_text("This is an old client and I want to add some historic information")
    |> assert_text("(Adds a few more steps - if you don't know what this is, leave unchecked)")
    |> assert_text("(Adds a few more steps - if you don't know what this is, leave unchecked)")
    |> assert_has(button("Cancel"))
  end

  defp assert_stepwise_changes(session) do
    session
    |> assert_text("Step 1")
    |> assert_text("Event")
    |> assert_text("Newborn")
    |> assert_text("Wedding")
    |> assert_text("Other")
  end

  defp assert_package_and_payment_fields(session) do
    session
    |> assert_text("Add Client: Package & Payment")
    |> assert_text("Package Details")
    |> assert_has(css("#form-package_payment_name"))
    |> assert_has(css("#form-package_payment_shoot_count"))
    |> assert_has(css("#form-package_payment_turnaround_weeks"))
    |> assert_text("Package Price")
    |> assert_text("The amount you’ve charged for your job")
    |> assert_text("(including download credits)")
    |> assert_has(css("#form-package_payment_base_price"))
    |> assert_text("How much of the creative session fee is for print credits?")
    |> assert_has(css("#form-package_payment_print_credits"))
    |> assert_text("The amount you’ve already collected")
    |> assert_has(css("#form-package_payment_collected_price"))
    |> assert_text("Remaining balance to collect with Picsello")
    |> assert_has(css(".checkbox", count: 2))
    |> assert_has(button("Go back"))
    |> assert_has(button("Next"))
  end

  defp assert_invoice_fields(session) do
    session
    |> assert_text("Add Client: Custom Invoice")
    |> assert_text("Balance to collect: #{@base_price}.00")
    |> assert_text("Payment 1")
    |> assert_has(css("#form-invoice_payment_schedules_0_due_date", visible: false))
    |> assert_has(css("#form-invoice_payment_schedules_0_price"))
    |> assert_text("Payment 2")
    |> assert_has(css("#form-invoice_payment_schedules_1_due_date", visible: false))
    |> assert_has(css("#form-invoice_payment_schedules_1_price"))
    |> assert_has(button("Remove"))
    |> assert_text("Remaining to collect: #{@base_price}.00")
    |> assert_text("limit two payments")
    |> assert_has(button("Go back"))
    |> assert_has(button("Next"))
  end

  defp fill_client_form(session) do
    session
    |> fill_in(css("#client_name"), with: @valid_client_params[:client_name])
    |> fill_in(css("#client_email"), with: @valid_client_params[:client_email])
  end

  defp fill_package_form(session) do
    session
    |> fill_in(css("#form-package_payment_name"), with: @package_name)
    |> find(
      text_field("The amount you’ve charged for your job"),
      &(&1 |> Element.clear() |> Element.fill_in(with: @base_price))
    )
  end

  defp fill_invoice_form(modal, session) do
    modal
    |> find(testid("payment-1"), &fill_in(&1, text_field("Payment amount"), with: "$5"))
    |> click(css("#payment-0"))

    session
    |> fill_in(css(".numInput.cur-year"), with: "2030")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("January")))
    |> click(css("[aria-label='January 1, 2030']"))

    modal
    |> find(testid("payment-2"), &fill_in(&1, text_field("Payment amount"), with: "$5"))
    |> click(css("#payment-1"))

    session
    |> fill_in(css(".numInput.cur-year"), with: "2030")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("January")))
    |> click(css("[aria-label='January 2, 2030']"))

    modal
  end
end
