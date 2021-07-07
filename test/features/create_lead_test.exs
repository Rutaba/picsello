defmodule Picsello.CreateLeadTest do
  use Picsello.FeatureCase, async: true

  import Picsello.JobFixtures

  setup :authenticated

  feature "user creates lead", %{session: session} do
    client_email = "taylor@example.com"
    client_name = "Elizabeth Taylor"

    session
    |> click(link("Create a lead"))
    |> fill_in(text_field("Client name"), with: client_name)
    |> fill_in(text_field("Client email"), with: client_email)
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h2", text: "Elizabeth Taylor Wedding"))
    |> assert_has(css("h1", text: "Add Package"))
    |> assert_has(
      css("select[name='package[package_template_id]'] option:checked", text: "+ New Package")
    )
    |> fill_in(text_field("Package name"), with: "Wedding Deluxe")
    |> fill_in(text_field("Package description"), with: "My greatest wedding package")
    |> fill_in(text_field("Package price"), with: "1234.50")
    |> click(css("option", text: "2"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Elizabeth Taylor Wedding"))
    |> assert_has(definition("Client", text: client_name))
    |> assert_has(definition("Client email", text: client_email))
    |> assert_has(definition("Type of job", text: "Wedding"))
    |> assert_has(definition("Job price", text: "$1,234.50"))
    |> assert_has(definition("Package", text: "Wedding Deluxe"))
    |> assert_has(definition("Package description", text: "My greatest wedding package"))
    |> assert_has(link("Add shoot details", count: 2))
    |> click(link("Picsello"))
    |> assert_has(link("View current leads"))
  end

  feature "user sees validation errors when creating job", %{session: session} do
    session
    |> click(link("Create a lead"))
    |> fill_in(text_field("Client name"), with: " ")
    |> fill_in(text_field("Client email"), with: " ")
    |> click(option("Wedding"))
    |> click(option("Select below"))
    |> assert_has(css("label", text: "Client name can't be blank"))
    |> assert_has(css("label", text: "Client email can't be blank"))
    |> assert_has(css("label", text: "Type of job can't be blank"))
    |> assert_has(css("button:disabled[type='submit']"))
  end

  feature "user sees error when creating client with duplicate email", %{
    session: session,
    user: user
  } do
    email = "taylor@example.com"

    fixture(:client, %{
      email: email,
      organization_id: user.organization_id
    })

    session
    |> click(link("Create a lead"))
    |> fill_in(text_field("Client email"), with: email)
    |> assert_has(css("label", text: "email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end
end
