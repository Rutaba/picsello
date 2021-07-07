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
    |> visit("/jobs/#{job.id}")
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
    |> assert_has(css("h1", text: "chute"))
    |> assert_has(definition("Shoot Date/Time", text: "Apr 5, 2040 - 12:00pm - 1.5 hrs"))
    |> assert_has(definition("Shoot Location", text: "On Location"))
    |> assert_has(definition("Notes", text: "my notes"))
    |> click(link("Edit shoot details"))
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
    |> assert_has(css("h1", text: "updated chute"))
    |> assert_has(definition("Shoot Date/Time", text: "May 5, 2040 - 12:00pm - 2 hrs"))
    |> assert_has(definition("Shoot Location", text: "In Studio"))
    |> assert_has(definition("Notes", text: "new notes"))
  end
end
