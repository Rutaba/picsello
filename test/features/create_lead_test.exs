defmodule Picsello.CreateLeadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  feature "user creates lead", %{session: session} do
    client_email = "taylor@example.com"
    client_name = "Elizabeth Taylor"
    client_phone = "(210) 111-1234"

    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client Name"), with: client_name)
    |> fill_in(text_field("Client Email"), with: client_email)
    |> fill_in(text_field("Client Phone"), with: client_phone)
    |> fill_in(text_field("Private Notes"), with: "things to know about")
    |> click(option("Wedding"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(testid("subheader", text: client_name))
    |> assert_has(testid("subheader", text: client_email))
    |> assert_has(testid("subheader", text: client_phone))
    |> assert_has(testid("notes", text: "things to know about"))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end

  feature "user sees validation errors when creating lead", %{session: session} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client Name"), with: " ")
    |> fill_in(text_field("Client Email"), with: " ")
    |> fill_in(text_field("Client Phone"), with: "123")
    |> click(option("Wedding"))
    |> click(option("Select below"))
    |> assert_has(css("label", text: "Client Name can't be blank"))
    |> assert_has(css("label", text: "Client Email can't be blank"))
    |> assert_has(css("label", text: "Client Phone is invalid"))
    |> assert_has(css("label", text: "Type of Photography can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user creates lead with job type 'other'", %{session: session} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client Name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client Email"), with: "taylor@example.com")
    |> fill_in(text_field("Client Phone"), with: "(210) 111-1234")
    |> click(option("Other"))
    |> find(css(".modal"), &wait_for_enabled_submit_button/1)
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Other"))
    |> click(link("Picsello"))
    |> find(testid("leads-card"))
    |> assert_text("1 pending lead")
  end
end
