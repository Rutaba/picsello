defmodule Picsello.CompleteJobTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    job = insert(:lead, user: user) |> promote_to_job()

    [job: job, session: session]
  end

  feature "user completes job", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#manage"))
    |> click(css("li", text: "Complete job"))
    |> click(button("Yes, mark complete"))
    |> assert_path("/jobs")
    |> assert_flash(:success, text: "Job completed")
    |> assert_has(css("*[role='status']", text: "Completed"))
    |> click(link(Job.name(job)))
    |> assert_has(css("*[role='status']", text: "Completed"))
    |> click(css("#manage"))
    |> assert_has(css("li", text: "Complete job", count: 0))
  end
end
