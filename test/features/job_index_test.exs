defmodule Picsello.JobIndexTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job

  setup do
    user = insert(:user)
    lead = insert(:job, %{user: user, type: "wedding"})
    job = insert(:job, %{user: user, type: "family", package: %{}})
    insert(:proposal, %{job: job, deposit_paid_at: DateTime.utc_now()})

    [user: user, job: job, lead: lead]
  end

  setup :authenticated

  feature "user with jobs looks at them", %{session: session, job: job, lead: lead} do
    session
    |> click(link("View current leads"))
    |> assert_has(link(Job.name(lead)))
    |> refute_has(link(Job.name(job)))
    |> click(link("back"))
    |> click(link("View jobs"))
    |> refute_has(link(Job.name(lead)))
    |> click(link(Job.name(job)))
    |> assert_has(link("Jobs"))
  end
end
