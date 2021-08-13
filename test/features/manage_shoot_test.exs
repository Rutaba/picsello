defmodule Picsello.ManageShootTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated

  setup %{session: session, user: user} do
    job =
      insert(:job, %{
        user: user,
        type: "wedding",
        notes: "They're getting married!",
        package: %{}
      })

    [job: job, session: session]
  end

  feature "user adds shoot details and updates it", %{session: session, job: job} do
    session
    |> visit("/leads/#{job.id}")
    |> click(link("Add shoot details", count: 2, at: 1))
    |> fill_in(text_field("Shoot name"), with: " ")
    |> assert_has(css("label", text: "Shoot name can't be blank"))
    |> fill_in(text_field("Shoot name"), with: "chute")
    |> fill_in(text_field("Shoot date"), with: "04052040\t1200P")
    |> click(option("1.5 hrs"))
    |> click(css("label", text: "On Location"))
    |> fill_in(text_field("Shoot notes"), with: "my notes")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> click(button("chute"))
    |> assert_has(radio_button("On Location", checked: true))
    |> assert_value(text_field("Shoot notes"), "my notes")
    |> assert_value(text_field("Shoot name"), "chute")
    |> assert_value(text_field("Shoot date"), "2040-04-05T12:00")
    |> assert_value(select("Shoot duration"), "90")
    |> assert_value(text_field("Shoot notes"), "my notes")
    |> fill_in(text_field("Shoot name"), with: " ")
    |> assert_has(css("label", text: "Shoot name can't be blank"))
    |> fill_in(text_field("Shoot name"), with: "updated chute")
    |> fill_in(text_field("Shoot date"), with: "05052040\t1200P")
    |> click(option("2 hrs"))
    |> click(css("label", text: "In Studio"))
    |> fill_in(text_field("Shoot notes"), with: "new notes")
    |> click(button("Save"))
    |> click(button("updated chute"))
    |> assert_value(text_field("Shoot date"), "2040-05-05T12:00")
    |> assert_value(select("Shoot duration"), "120")
    |> assert_has(radio_button("In Studio", checked: true))
    |> assert_value(text_field("Shoot notes"), "new notes")
  end
end
