defmodule Picsello.UserManagesContactsTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query

  setup :onboarded
  setup :authenticated

  feature "adds new contact", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Contacts"))
    |> assert_text("You have 0 contacts")
    |> click(button("Add contact"))
    |> fill_in(text_field("Name"), with: " ")
    |> assert_text("Name can't be blank")
    |> fill_in(text_field("Name"), with: "John")
    |> fill_in(text_field("Email"), with: "john@example.com")
    |> wait_for_enabled_submit_button(text: "Save")
    |> click(button("Save"))
    |> assert_text("You have 1 contact")
    |> assert_text("John")
    |> assert_text("john@example.com")
  end
end
