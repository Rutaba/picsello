defmodule Picsello.JobIndexTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job

  setup do
    user = insert(:user)
    lead = insert(:job, user: user, type: "wedding")
    job = insert(:job, user: user, type: "family", package: %{shoot_count: 1})
    insert(:shoot, job: job)

    insert(:proposal,
      job: job,
      deposit_paid_at: DateTime.utc_now(),
      accepted_at: DateTime.utc_now(),
      signed_at: DateTime.utc_now()
    )

    [user: user, job: job, lead: lead]
  end

  setup :authenticated

  feature "user with jobs looks at them", %{session: session, job: job, lead: lead} do
    session
    |> click(link("View current leads"))
    |> assert_has(link(Job.name(lead)))
    |> refute_has(link(Job.name(job)))
    |> click(link("Picsello"))
    |> click(link("View jobs"))
    |> refute_has(link(Job.name(lead)))
    |> click(link(Job.name(job)))
    |> assert_has(link("Jobs"))
  end

  feature "leads show status", %{session: session, lead: created_lead, user: user} do
    archived_lead = insert(:job, user: user, type: "family", archived_at: DateTime.utc_now())

    refute Job.name(archived_lead) == Job.name(created_lead)

    session
    |> click(link("View current leads"))
    |> assert_has(link(Job.name(archived_lead), text: "Archived"))
    |> assert_has(link(Job.name(created_lead), text: "Created"))
  end

  feature "elapsed shoot dates are hidden", %{session: session, job: future_job, user: user} do
    elapsed_job = insert(:job, type: "wedding", user: user)
    insert(:proposal, %{job: elapsed_job, deposit_paid_at: DateTime.utc_now()})

    future_job_shoot =
      insert(:shoot, job: future_job, starts_at: DateTime.utc_now() |> DateTime.add(100))

    elapsed_job_shoot =
      insert(:shoot, job: elapsed_job, starts_at: DateTime.utc_now() |> DateTime.add(-100))

    session
    |> click(link("View jobs"))
    |> assert_has(
      link(Job.name(future_job),
        text: "On #{future_job_shoot.starts_at |> Calendar.strftime("%B")}"
      )
    )
    |> refute_has(
      link(Job.name(elapsed_job),
        text: "On #{elapsed_job_shoot.starts_at |> Calendar.strftime("%B")}"
      )
    )
  end
end
