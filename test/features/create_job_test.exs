defmodule Picsello.CreateJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Client, Repo}

  setup :authenticated

  feature "user creates job", %{session: session} do
    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client name"), with: "Elizabeth Taylor")
    |> fill_in(text_field("Client email"), with: "taylor@example.com")
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h2", text: "Elizabeth Taylor Wedding"))
    |> assert_has(css("h1", text: "Add Package"))
  end

  feature "user sees validation errors when creating job", %{session: session} do
    session
    |> click(link("Create a Job"))
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

    Client.create_changeset(%{
      email: email,
      name: "anything",
      organization_id: user.organization_id
    })
    |> Repo.insert!()

    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client email"), with: email)
    |> assert_has(css("label", text: "email has already been taken"))
    |> assert_has(css("button:disabled[type='submit']"))
  end
end
