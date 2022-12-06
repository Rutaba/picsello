defmodule Picsello.ClientsIndexTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query

  alias Picsello.{Repo, Job, Client}

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    client =
      insert(:client,
        user: user,
        name: "Elizabeth Taylor",
        email: "taylor@example.com",
        phone: "(210) 111-1234"
      )

    lead = insert(:lead, client: client, user: user)
    [client: client, session: session, user: user, lead: lead]
  end

  def fill_in_package_form(session) do
    session
    |> fill_in(text_field("Title"), with: "Wedding Deluxe")
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> fill_in(text_field("Image Turnaround Time"), with: "2")
    |> find(
      text_field("The amount you’ve charged for your job"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$1000.00"))
    )
    |> find(
      text_field("How much of the creative session fee is for print credits"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$100.00"))
    )
    |> find(
      text_field("The amount you’ve already collected"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$200.00"))
    )
    |> assert_has(definition("Remaining balance to collect with Picsello", text: "$800.00"))
    |> scroll_into_view(css("#download_is_enabled_true"))
    |> click(radio_button("Package includes a specified number of Digital Images"))
    |> click(checkbox("download[includes_credits]"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "2"))
    )
    |> scroll_into_view(css("#download_is_custom_price"))
    |> click(checkbox("download[is_custom_price]"))
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(checkbox("download_is_buy_all"))
    |> find(
      text_field("download[buy_all]"),
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
    |> find(testid("payment-2"), &fill_in(&1, text_field("Due"), with: "01/02/2030"))
    |> assert_text("Remaining to collect: $0.00")
  end

  @name "John"
  @email "john@example.com"
  @phone "(555) 123-1234"
  feature "adds new client and edits it", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> assert_has(testid("client-count", text: "1"))
    |> click(button("Add client"))
    |> fill_in(text_field("Email"), with: " ")
    |> assert_text("Email can't be blank")
    |> fill_in(text_field("Name"), with: @name)
    |> fill_in(text_field("Email"), with: @email)
    |> fill_in(text_field("Phone"), with: @phone)
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> click(link("All Clients"))
    |> assert_has(testid("client-count", text: "2"))
    |> assert_text(@name)
    |> assert_text(@email)
    |> click(button("Manage", count: 2, at: 1))
    |> click(button("Details"))
    |> assert_text("Client: #{@name}")
    |> click(button("Edit Contact"))
    |> assert_text("Edit Client: General Details")
    |> assert_value(text_field("Name"), @name)
    |> assert_value(text_field("Email"), @email)
    |> assert_value(text_field("Phone"), @phone)
    |> fill_in(text_field("Name"), with: "Josh")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Client: Josh")
  end

  feature "adds client without name and update its email", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> assert_has(testid("client-count", text: "1"))
    |> click(button("Add client"))
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> click(link("All Clients"))
    |> assert_has(testid("client-count", text: "2"))
    |> assert_text("john@example.com")
    |> click(button("Manage", count: 2, at: 1))
    |> click(button("Details"))
    |> assert_text("Client: john@example.com")
    |> click(button("Edit Contact"))
    |> fill_in(text_field("Email"), with: "john2@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("john2@example.com")
  end

  feature "edits client from actions that already has a job", %{
    session: session,
    client: client,
    lead: _lead
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage"))
    |> click(button("Details"))
    |> assert_text("Client: #{client.name}")
    |> click(button("Edit Contact"))
    |> fill_in(text_field("Name"), with: " ")
    |> assert_text("Name can't be blank")
    |> fill_in(text_field("Name"), with: "John")
    |> fill_in(text_field("Phone"), with: "")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Client: John")
  end

  feature "edits client and add private notes", %{session: session, client: client} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage"))
    |> click(button("Details"))
    |> assert_text("Client: #{client.name}")
    |> find(testid("card-Private notes"), &click(&1, button("Edit")))
    |> fill_in(text_field("Private Notes"), with: "here are my private notes")
    |> click(button("Save"))
    |> assert_has(testid("card-Private notes", text: "here are my private notes"))
    |> find(testid("card-Private notes"), &click(&1, button("Edit")))
    |> assert_value(text_field("Private Notes"), "here are my private notes")
    |> find(css(".modal"), &click(&1, button("Clear")))
    |> assert_value(text_field("Private Notes"), "")
    |> fill_in(text_field("Private Notes"), with: "here are my 2nd private notes")
    |> click(button("Save"))
    |> assert_has(testid("card-Private notes", text: "here are my 2nd private notes"))
  end

  feature "creates gallery from client", %{
    session: session,
    client: _client
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage"))
    |> click(button("Create gallery"))
    |> click(button("Next", count: 3, at: 0))
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> find(select("Type of Photography"), &click(&1, option("event")))
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> scroll_into_view(testid("print"))
    |> click(radio_button("Gallery does not include Print Credits"))
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(radio_button("Gallery includes unlimited digital downloads"))
    |> within_modal(&click(&1, button("Save")))
    |> click(button("Great!"))
    |> assert_url_contains("galleries")
  end

  @client_name "Elizabeth Taylor"
  feature "imports job from client", %{
    session: session,
    client: _client
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage"))
    |> click(button("Import job"))
    |> scroll_into_view(css("label", text: "Wedding"))
    |> click(css("label", text: "Wedding"))
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> assert_text("Import Existing Job: Package & Payment")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_package_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> assert_text("Import Existing Job: Custom Invoice")
    |> assert_text("Client: #{@client_name}")
    |> fill_in_payments_form()
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> within_modal(&click(&1, button("Finish")))
    |> assert_has(link("Contact Details"))
    |> assert_has(link("Job Details"))
    |> assert_has(link("Order History"))
    |> assert_text("Job Details")
    |> assert_text("Actions")

    job = Job |> order_by(:id) |> limit(1) |> Repo.one() |> Repo.preload([:client])

    assert %Job{
             type: "wedding"
           } = job

    assert %Client{
             email: "taylor@example.com",
             name: "Elizabeth Taylor",
             phone: "(210) 111-1234"
           } = job.client
  end

  feature "send email from client", %{
    session: session,
    client: client
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage"))
    |> click(button("Send email"))
    |> refute_has(select("Select email preset"))
    |> take_screenshot()
    |> fill_in(text_field("Subject line"), with: "Here is what I propose")
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> click(button("Send"))
    |> assert_flash(:success, text: "Email sent to #{client.name}!")
  end

  feature "user archives client", %{
    session: session,
    client: _client,
    user: user
  } do
    insert(:client,
      user: user,
      name: "Mary Jane"
    )

    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage", count: 2, at: 0))
    |> click(button("Archive"))
    |> click(button("Yes, archive"))
    |> assert_flash(:success, text: "Client archived successfully")
    |> assert_text("Mary Jane")
  end

  feature "pagination", %{session: session, user: user} do
    insert_list(12, :client, user: user)

    session
    |> visit("/clients")
    |> assert_text("Results: 1 – 12 of 13")
    |> assert_has(testid("client-row", count: 12))
    |> assert_has(css("button:disabled[title='Previous page']"))
    |> click(button("Next page"))
    |> assert_text("Results: 13 – 13 of 13")
    |> assert_has(testid("client-row", count: 1))
    |> assert_has(css("button:disabled[title='Next page']"))
    |> click(button("Previous page"))
    |> assert_text("Results: 1 – 12 of 13")
    |> click(css("select", text: "12"))
    |> click(css("option", text: "24"))
    |> assert_text("Results: 1 – 13 of 13")
  end
end
