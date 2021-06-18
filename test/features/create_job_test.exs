defmodule Picsello.CreateJobTest do
  use Picsello.FeatureCase

  setup :authenticated

  feature "user creates job", %{session: session} do
    session
    |> click(link("Create a Job"))
    |> fill_in(text_field("Client name"), with: "Jane")
    |> fill_in(text_field("Client email"), with: "jane@example.com")
    |> click(option("Wedding"))
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
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
end
