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

    insert(:client, %{
      organization: user.organization,
      name: "John Snow",
      phone: "(241) 567-2352",
      email: "snow@example.com"
    })

    insert(:client, %{
      organization: user.organization,
      name: "Michael Stark",
      phone: "(442) 567-2321",
      email: "stark@example.com"
    })

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
    |> scroll_into_view(css("#download_status_limited"))
    |> click(css("#download_status_limited"))
    |> find(
      text_field("download_count"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "2"))
    )
    |> scroll_into_view(css("#download_is_custom_price"))
    |> find(
      text_field("download[each_price]"),
      &(&1 |> Element.clear() |> Element.fill_in(with: "$2"))
    )
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(css("#download_is_buy_all"))
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
    |> click(button("Add client"))
    |> fill_in(text_field("Email"), with: " ")
    |> assert_text("Email can't be blank")
    |> fill_in(text_field("Name"), with: @name)
    |> fill_in(text_field("Email"), with: @email)
    |> fill_in(text_field("Phone"), with: @phone)
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> click(link("All Clients"))
    |> assert_text(@name)
    |> assert_text(@email)
    |> click(button("Manage", count: 4, at: 1))
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
    |> find(css("#intro_hints_only"), &click(&1, button("Add client")))
    |> fill_in(text_field("Email"), with: "jane@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> click(link("All Clients"))
    |> assert_text("jane@example.com")
    |> click(button("Manage", count: 4, at: 3))
    |> click(button("Details"))
    |> assert_text("Client: jane@example.com")
    |> click(button("Edit Contact"))
    |> fill_in(text_field("Email"), with: "jane_mary@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("jane_mary@example.com")
  end

  feature "edits client from actions that already has a job", %{
    session: session,
    client: client,
    lead: _lead
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage", count: 3, at: 0))
    |> click(button("Details"))
    |> assert_text("Client: #{client.name}")
    |> click(button("Edit Contact"))
    |> fill_in(text_field("Name"), with: " ")
    |> assert_text("Name can't be blank")
    |> fill_in(text_field("Name"), with: "Liza Taylor")
    |> fill_in(text_field("Phone"), with: "")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Client: Liza Taylor")
  end

  feature "edits client and add private notes", %{session: session, client: client} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage", count: 3, at: 0))
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
    |> click(button("Manage", count: 3, at: 0))
    |> click(button("Create gallery"))
    |> click(button("Next", count: 2, at: 0))
    |> click(css("label", text: "Wedding"))
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> scroll_into_view(testid("print"))
    |> click(radio_button("Gallery does not include Print Credits"))
    |> scroll_into_view(css("#download_is_buy_all"))
    |> click(css("#download_status_unlimited"))
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
    |> click(button("Manage", count: 3, at: 0))
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
    session: session
  } do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Clients"))
    |> click(button("Manage", count: 3, at: 0))
    |> click(button("Send email"))
    |> refute_has(select("Select email preset"))
    |> fill_in(text_field("Subject line"), with: "Here is what I propose")
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> click(button("Send"))
    |> assert_flash(:success, text: "Email sent!")
    |> click(button("Manage", count: 3, at: 1))
    |> click(button("Send email"))
    |> within_modal(fn modal ->
      modal
      |> click(button("Add Cc"))
      |> fill_in(text_field("cc_email"), with: "taylor@example.com; snow@example.com")
      |> click(button("Add Bcc"))
      |> fill_in(text_field("bcc_email"), with: "new")
      |> assert_has(testid("bcc-error"))
      |> click(button("remove-bcc"))
      |> fill_in(text_field("search_phrase"), with: "stark")
      |> assert_has(css("#search_results"))
      |> find(testid("search-row", count: 1, at: 0), fn row ->
        row
        |> click(button("Add to"))
      end)
      |> fill_in(text_field("Subject line"), with: "My subject")
      |> scroll_to_bottom()
      |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
      |> send_keys(["This is 1st line", :enter, "2nd line"])
      |> click(button("Send"))
    end)
    |> assert_flash(:success, text: "Email sent!")
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
    |> click(button("Manage", count: 4, at: 0))
    |> click(button("Archive"))
    |> click(button("Yes, archive"))
    |> assert_flash(:success, text: "Client archived successfully")
    |> assert_text("Mary Jane")
  end

  feature "pagination", %{session: session, user: user} do
    insert_list(12, :client, user: user)

    session
    |> visit("/clients")
    |> scroll_to_bottom()
    |> assert_text("Results: 1 – 12 of 15")
    |> assert_has(testid("client-row", count: 12))
    |> assert_has(css("button:disabled[title='Previous page']"))
    |> click(button("Next page"))
    |> assert_text("Results: 13 – 15 of 15")
    |> assert_has(testid("client-row", count: 3))
    |> assert_has(css("button:disabled[title='Next page']"))
    |> click(button("Previous page"))
    |> assert_text("Results: 1 – 12 of 15")
    |> click(css("select", text: "12"))
    |> click(css("option", text: "24"))
  end
end
