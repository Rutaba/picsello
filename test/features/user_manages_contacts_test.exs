defmodule Picsello.UserManagesContactsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "adds new contact and edits it", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 0 contacts")
    |> click(button("Add contact"))
    |> fill_in(text_field("Email"), with: " ")
    |> assert_text("Email can't be blank")
    |> fill_in(text_field("Name"), with: "John")
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> fill_in(text_field("Phone"), with: "(555) 123-1234")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Manage your 1 contact")
    |> assert_flash(:success, text: "Contact saved")
    |> assert_text("John")
    |> assert_text("john@example.com")
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit contact")
    |> assert_value(text_field("Name"), "John")
    |> assert_value(text_field("Email"), "john@example.com")
    |> assert_value(text_field("Phone"), "(555) 123-1234")
    |> fill_in(text_field("Name"), with: "Josh")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Josh")
    |> assert_text("Manage your 1 contact")
    |> assert_flash(:success, text: "Contact saved")
  end

  feature "adds contact without name", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 0 contacts")
    |> click(button("Add contact"))
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Manage your 1 contact")
    |> assert_flash(:success, text: "Contact saved")
    |> assert_text("john@example.com")
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit contact")
    |> fill_in(text_field("Email"), with: "john2@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Contact saved")
    |> assert_text("john2@example.com")
  end

  feature "edits contact that already has a job", %{session: session, user: user} do
    insert(:lead, user: user)

    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 1 contact")
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_text("Edit contact")
    |> fill_in(text_field("Name"), with: " ")
    |> assert_text("Name can't be blank")
    |> fill_in(text_field("Phone"), with: " ")
    |> assert_text("Phone can't be blank")
    |> fill_in(text_field("Name"), with: "John")
    |> fill_in(text_field("Phone"), with: "(555) 9876-1234")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("Manage your 1 contact")
    |> assert_flash(:success, text: "Contact saved")
    |> assert_text("John")
  end

  feature "creates lead from contact without name and phone", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: nil,
      phone: nil,
      email: "elizabeth@example.com"
    )

    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 1 contact")
    |> click(button("Manage"))
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client Name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client Phone"), with: "(555) 123-4567")
    |> fill_in(text_field("Private Notes"), with: "things to know about")
    |> click(option("Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "elizabeth@example.com"))
    |> assert_has(testid("card-Communications", text: "(555) 123-4567"))
    |> assert_has(testid("card-Private notes", text: "things to know about"))
  end

  feature "creates lead from contact without phone", %{session: session, user: user} do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      phone: nil,
      email: "elizabeth@example.com"
    )

    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 1 contact")
    |> click(button("Manage"))
    |> click(button("Create a lead"))
    |> assert_disabled(text_field("Client Name"))
    |> fill_in(text_field("Client Phone"), with: "(555) 123-4567")
    |> fill_in(text_field("Private Notes"), with: "things to know about")
    |> click(option("Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "elizabeth@example.com"))
    |> assert_has(testid("card-Communications", text: "(555) 123-4567"))
    |> assert_has(testid("card-Private notes", text: "things to know about"))
  end

  feature "creates lead from contact with existing name and phone", %{
    session: session,
    user: user
  } do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      phone: "(555) 123-4567",
      email: "elizabeth@example.com"
    )

    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 1 contact")
    |> click(button("Manage"))
    |> click(button("Create a lead"))
    |> assert_disabled(text_field("Client Name"))
    |> assert_disabled(text_field("Client Phone"))
    |> fill_in(text_field("Private Notes"), with: "things to know about")
    |> click(option("Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(testid("card-Communications", text: "Elizabeth Taylor"))
    |> assert_has(testid("card-Communications", text: "elizabeth@example.com"))
    |> assert_has(testid("card-Communications", text: "(555) 123-4567"))
    |> assert_has(testid("card-Private notes", text: "things to know about"))
  end

  feature "user archives contact", %{
    session: session,
    user: user
  } do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor"
    )

    insert(:client,
      user: user,
      name: "Mary Jane"
    )

    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("Manage your 2 contacts")
    |> click(button("Manage", count: 2, at: 0))
    |> click(button("Archive"))
    |> click(button("Yes, archive"))
    |> assert_flash(:success, text: "Contact archived successfully")
    |> assert_text("Manage your 1 contact")
    |> assert_text("Mary Jane")
  end
end
