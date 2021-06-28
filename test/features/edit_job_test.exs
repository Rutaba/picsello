defmodule Picsello.EditJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Client, Repo, Job, Package}

  setup :authenticated

  setup %{session: session, user: user} do
    client =
      Client.create_changeset(%{
        email: "taylor@example.com",
        name: "Elizabeth Taylor",
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    package =
      Package.create_changeset(%{
        price: 100,
        name: "My Package Template",
        description: "My custom description",
        shoot_count: 2,
        organization_id: user.organization_id
      })
      |> Repo.insert!()

    job =
      Job.create_changeset(%{client_id: client.id, type: "wedding"})
      |> Job.add_package_changeset(%{package_id: package.id})
      |> Repo.insert!()

    session
    |> visit("/jobs/#{job.id}")

    [job: job, session: session]
  end

  feature "user edits a job", %{session: session, job: job} do
    session
    |> click(link("Edit Job"))
    |> assert_path("/jobs/#{job.id}/edit")
    |> assert_has(link("Cancel Edit Job"))
    |> assert_value(select("Type of job"), "wedding")
    |> assert_value(text_field("Job price"), "$1.00")
    |> assert_value(text_field("Package", at: 0, count: 2), "My Package Template")
    |> assert_value(text_field("Package description"), "My custom description")
    |> click(option("Family"))
    |> fill_in(text_field("Job price"), with: "")
    |> assert_has(css("label", text: "Job price can't be blank"))
    |> fill_in(text_field("Job price"), with: "2.00")
    |> fill_in(text_field("Package", at: 0, count: 2), with: "My Greatest Package")
    |> fill_in(text_field("Package description"), with: "indescribably great.")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_path("/jobs/#{job.id}")
    |> assert_has(css(".alert-info", text: "Job updated successfully."))
    |> assert_has(definition("Job price", text: "$2.00"))
    |> assert_has(definition("Type of job", text: "Family"))
    |> assert_has(definition("Package", text: "My Greatest Package"))
    |> assert_has(definition("Package description", text: "indescribably great."))
  end

  feature "user adds shoot details and updates it", %{session: session} do
    session
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
