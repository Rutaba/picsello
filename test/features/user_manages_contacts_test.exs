defmodule Picsello.UserManagesContactsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "adds new contact and edits it", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("You have 0 contacts")
    |> click(button("Add contact"))
    |> fill_in(text_field("Email"), with: " ")
    |> assert_text("Email can't be blank")
    |> fill_in(text_field("Name"), with: "John")
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> fill_in(text_field("Phone"), with: "(555) 123-1234")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("You have 1 contact")
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
    |> assert_text("You have 1 contact")
    |> assert_flash(:success, text: "Contact saved")
  end

  feature "adds contact without name", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("You have 0 contacts")
    |> click(button("Add contact"))
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("You have 1 contact")
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
    |> assert_text("You have 1 contact")
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
    |> assert_text("You have 1 contact")
    |> assert_flash(:success, text: "Contact saved")
    |> assert_text("John")
  end
end
