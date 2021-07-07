defmodule Picsello.EditJobTest do
  use Picsello.FeatureCase, async: true

  import Picsello.JobFixtures

  setup :authenticated

  setup %{session: session, user: user} do
    job =
      fixture(:job, %{
        user: user,
        type: "wedding",
        notes: "They're getting married!"
      })

    [job: job, session: session]
  end

  feature "user edits a job", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(link("Edit lead"))
    |> assert_has(link("Cancel edit lead"))
    |> assert_value(select("Type of photography"), "wedding")
    |> assert_value(text_field("Lead notes"), "They're getting married!")
    |> click(option("Other"))
    |> fill_in(text_field("Lead notes"), with: "They're getting hitched!")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("h1", text: "Other"))
    |> assert_has(definition("Lead notes", text: "They're getting hitched!"))
  end
end
