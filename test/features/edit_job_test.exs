defmodule Picsello.EditJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, Shoot}

  import Picsello.JobFixtures

  setup :authenticated

  setup %{session: session, user: user} do
    job =
      fixture(:job, %{
        user: user,
        type: "wedding",
        notes: "They're getting married!",
        package: %{
          name: "My Package Template",
          description: "My custom description",
          shoot_count: 2,
          price: 100
        }
      })

    [job: job, session: session]
  end

  feature "user edits a job", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(link("Edit Lead"))
    |> assert_path("/jobs/#{job.id}/edit")
    |> assert_has(link("Cancel Edit Job"))
    |> assert_value(select("Type of job"), "wedding")
    |> assert_value(text_field("Lead notes"), "They're getting married!")
    |> assert_value(text_field("Job price"), "$1.00")
    |> assert_value(text_field("Package", at: 0, count: 2), "My Package Template")
    |> assert_value(text_field("Package description"), "My custom description")
    |> click(option("Family"))
    |> fill_in(text_field("Job price"), with: "")
    |> assert_has(css("label", text: "Job price can't be blank"))
    |> fill_in(text_field("Job price"), with: "2.00")
    |> fill_in(text_field("Package", at: 0, count: 2), with: "My Greatest Package")
    |> fill_in(text_field("Package description"), with: "indescribably great.")
    |> fill_in(text_field("Lead notes"), with: "They're getting hitched!")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_path("/jobs/#{job.id}")
    |> assert_has(css(".alert-info", text: "Job updated successfully."))
    |> assert_has(definition("Package price", text: "$2.00"))
    |> assert_has(definition("Package name", text: "My Greatest Package"))
    |> assert_has(definition("Package description", text: "indescribably great."))
    |> assert_has(definition("Lead notes", text: "They're getting hitched!"))
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

  feature "user deletes shoot", %{session: session, job: job} do
    fixture(:shoot, %{job_id: job.id})

    session
    |> visit("/jobs/#{job.id}")
    |> assert_has(link("Add shoot details", count: 1))
    |> click(link("Edit shoot details"))
    |> click(link("Delete shoot"))
    |> assert_has(link("Add shoot details", count: 2))

    assert Repo.aggregate(Shoot, :count) == 0
  end
end
