defmodule Picsello.JobIndexTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo}

  setup do
    user = insert(:user)
    lead = insert(:job, user: user, type: "wedding")
    job = insert(:job, user: user, type: "family", package: %{shoot_count: 1})
    shoot = insert(:shoot, job: job)

    proposal =
      insert(:proposal,
        job: job,
        deposit_paid_at: DateTime.utc_now(),
        accepted_at: DateTime.utc_now(),
        signed_at: DateTime.utc_now()
      )

    [user: user, job: job, lead: lead, shoot: shoot, proposal: proposal]
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

  feature "empty jobs", %{session: session, job: job, proposal: proposal, shoot: shoot} do
    session
    |> visit("/jobs")
    |> refute_has(link("Go to your leads"))

    Repo.delete(proposal)
    Repo.delete(shoot)
    Repo.delete(job)

    session
    |> visit("/jobs")
    |> assert_text("You don't have any jobs at the moment")
    |> click(link("Go to your leads"))
    |> assert_path("/leads")
  end

  feature "empty leads", %{session: session, lead: lead} do
    session
    |> visit("/leads")
    |> refute_has(link("Create a lead"))

    Repo.delete(lead)

    session
    |> visit("/leads")
    |> assert_text("You don't have any leads at the moment")
    |> click(link("Create a lead"))
    |> assert_has(css("h1", text: "Create a lead"))
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

  feature "pagination", %{session: session, user: user} do
    insert_list(6, :job, user: user)

    session
    |> visit("/leads")
    |> assert_text("Results: 1 – 6 of 7")
    |> assert_has(css("ul li", count: 6))
    |> assert_has(css("button:disabled[title='Previous page']"))
    |> click(button("Next page"))
    |> assert_text("Results: 7 – 7 of 7")
    |> assert_has(css("ul li", count: 1))
    |> assert_has(css("button:disabled[title='Next page']"))
    |> click(button("Previous page"))
    |> assert_text("Results: 1 – 6 of 7")
    |> find(select("per-page"), &click(&1, option("12")))
    |> assert_text("Results: 1 – 7 of 7")
  end
end
