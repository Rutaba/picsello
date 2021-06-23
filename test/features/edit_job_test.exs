defmodule Picsello.EditJobTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Client, Repo, Job, Package}

  setup :authenticated

  feature "user edits a job", %{session: session, user: user} do
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
end
