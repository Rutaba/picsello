defmodule Picsello.CreateLeadTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated

  feature "user creates lead", %{session: session} do
    client_email = "taylor@example.com"
    client_name = "Elizabeth Taylor"

    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client name"), with: client_name)
    |> fill_in(text_field("Client email"), with: client_email)
    |> fill_in(text_field("Lead notes"),
      with: """
          things to know about:
          1) lumens
      """
    )
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(definition("Client", text: client_name))
    |> assert_has(definition("Client email", text: client_email))
    |> assert_has(definition("Lead notes", text: "things to know about"))
    |> click(link("Picsello"))
    |> assert_has(link("View current leads"))
  end

  feature "user sees validation errors when creating lead", %{session: session} do
    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client name"), with: " ")
    |> fill_in(text_field("Client email"), with: " ")
    |> click(option("Wedding"))
    |> click(option("Select below"))
    |> assert_has(css("label", text: "Client name can't be blank"))
    |> assert_has(css("label", text: "Client email can't be blank"))
    |> assert_has(css("label", text: "Type of photography can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user sees error when creating client with duplicate email", %{
    session: session,
    user: user
  } do
    email = "taylor@example.com"

    insert(:client, %{email: email, user: user})

    session
    |> click(button("Create a lead"))
    |> fill_in(text_field("Client email"), with: email)
    |> assert_has(css("label", text: "email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end
end
