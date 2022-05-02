defmodule Picsello.JobIndexTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization}

  @leads_card css("li[title='Leads']")
  @jobs_card css("li[title='Jobs']")

  setup do
    user = insert(:user)
    lead = insert(:lead, user: user, type: "wedding")

    %{shoots: [shoot], booking_proposals: [proposal]} =
      job =
      insert(:lead, user: user, type: "family", package: %{shoot_count: 1})
      |> promote_to_job()
      |> Repo.preload([:shoots, :booking_proposals])

    [user: user, job: job, lead: lead, shoot: shoot, proposal: proposal]
  end

  setup :onboarded
  setup :authenticated

  setup do
    Repo.update_all(Organization, set: [stripe_account_id: "stripe_id"])

    Mox.stub(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    :ok
  end

  def delete_job() do
    Repo.delete_all(Picsello.BookingProposal)
    Repo.delete_all(Picsello.Shoot)
    Repo.delete_all(Picsello.PaymentSchedule)
    Repo.delete_all(Picsello.Job)
  end

  feature "user with jobs looks at them", %{session: session, job: job, lead: lead} do
    session
    |> click(@leads_card)
    |> assert_has(css("main > ul > li", count: 1))
    |> assert_has(link(Job.name(lead)))
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(css("main > ul > li", count: 1))
    |> assert_has(link(Job.name(job)))
    |> click(link(Job.name(job)))
    |> assert_has(link("Jobs"))
  end

  feature "empty jobs", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Jobs"))
    |> refute_has(link("Go to your leads"))
    |> refute_has(Query.link("Create a lead"))

    delete_job()

    session
    |> visit("/jobs")
    |> assert_text("You don't have any jobs at the moment")
    |> assert_has(link("Create a lead"))
  end

  feature "empty jobs with stripe not enabled", %{session: session} do
    Repo.update_all(Organization, set: [stripe_account_id: nil])
    delete_job()

    session
    |> click(css("#hamburger-menu"))
    |> click(link("Jobs"))
    |> assert_text("A Stripe account is required for job import")
    |> assert_has(button("Set up Stripe"))
  end

  feature "empty leads", %{session: session, lead: lead} do
    session
    |> click(link("Leads"))
    |> click(link("Create a lead"))
    |> assert_has(css("h1", text: "Create a lead"))

    Repo.delete(lead)

    session
    |> visit("/leads")
    |> assert_text("You don't have any leads at the moment")
    |> click(link("Create a lead"))
    |> assert_has(css("h1", text: "Create a lead"))
  end

  feature "leads show status", %{session: session, lead: created_lead, user: user} do
    archived_lead = insert(:lead, user: user, type: "family", archived_at: DateTime.utc_now())

    refute Job.name(archived_lead) == Job.name(created_lead)

    session
    |> click(@leads_card)
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
    |> assert_has(link(Job.name(archived_lead), text: "Archived"))
    |> assert_has(link(Job.name(created_lead), text: "Created"))
  end

  feature "elapsed shoot dates are hidden", %{session: session, job: future_job, user: user} do
    elapsed_job = insert(:lead, type: "wedding", user: user) |> promote_to_job()

    future_job_shoot =
      insert(:shoot, job: future_job, starts_at: DateTime.utc_now() |> DateTime.add(100))

    elapsed_job_shoot =
      insert(:shoot, job: elapsed_job, starts_at: DateTime.utc_now() |> DateTime.add(-100))

    session
    |> click(@jobs_card)
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
    insert_list(12, :lead, user: user)

    session
    |> visit("/leads")
    |> assert_text("Results: 1 – 12 of 13")
    |> assert_has(css("main > ul > li", count: 12))
    |> assert_has(css("button:disabled[title='Previous page']"))
    |> click(button("Next page"))
    |> assert_text("Results: 13 – 13 of 13")
    |> assert_has(css("main > ul > li", count: 1))
    |> assert_has(css("button:disabled[title='Next page']"))
    |> click(button("Previous page"))
    |> assert_text("Results: 1 – 12 of 13")
    |> click(css("#page-dropdown"))
    |> click(css("label", text: "24"))
    |> assert_text("Results: 1 – 13 of 13")
  end
end
