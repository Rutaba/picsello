defmodule Picsello.JobIndexTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Job, Repo, Organization}

  @leads_card button("Leads")
  @jobs_card button("Jobs")

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
    Repo.delete_all(Picsello.Contract)
    Repo.delete_all(Picsello.Job)
  end

  feature "user with jobs looks at them", %{session: session, job: job, lead: lead} do
    session
    |> click(@leads_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(Job.name(lead)))
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(testid("job-row", count: 1))
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
    |> assert_text("Meet Jobs")
    |> assert_has(link("Import a job"))
  end

  feature "empty leads", %{session: session, lead: lead} do
    session
    |> click(css("#sub-menu", text: "Your work"))
    |> click(link("Leads"))
    |> click(link("Create a lead"))
    |> assert_has(css("h1", text: "Create a lead"))

    Repo.delete(lead)

    session
    |> visit("/leads")
    |> assert_text("Meet Leads")
    |> click(link("Create a lead", count: 2, at: 1))
    |> assert_has(css("h1", text: "Create a lead"))
  end

  feature "booking leads are not displayed", %{session: session, user: user} do
    insert(:lead, user: user, archived_at: DateTime.utc_now())
    template = insert(:package_template, user: user)
    event = insert(:booking_event, package_template_id: template.id)
    insert(:lead, user: user, archived_at: DateTime.utc_now(), booking_event_id: event.id)
    insert(:lead, user: user, booking_event_id: event.id)

    session
    |> visit("/leads")
    |> assert_has(testid("job-row", count: 1))
  end

  feature "leads show status", %{session: session, lead: created_lead, user: user} do
    archived_lead = insert(:lead, user: user, type: "family", archived_at: DateTime.utc_now())

    refute Job.name(archived_lead) == Job.name(created_lead)

    session
    |> click(@leads_card)
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
    |> assert_has(link(Job.name(archived_lead), count: 0))
    |> assert_has(link(Job.name(created_lead), text: "Created"))
  end

  feature "edits job", %{
    session: session,
    job: job,
    lead: lead
  } do
    session
    |> click(@leads_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(lead.client.name))
    |> assert_has(link(Job.name(lead)))
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_url_contains("leads/#{lead.id}")
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(job.client.name))
    |> assert_has(link(Job.name(job)))
    |> click(button("Manage"))
    |> click(button("Edit"))
    |> assert_url_contains("jobs/#{job.id}")
  end

  feature "visits client details", %{
    session: session,
    job: job,
    lead: lead
  } do
    session
    |> click(@leads_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(lead.client.name))
    |> assert_has(link(Job.name(lead)))
    |> click(button("Manage"))
    |> click(button("View Client"))
    |> assert_url_contains("clients/#{lead.client_id}")
    |> assert_has(testid("client-details"))
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(job.client.name))
    |> assert_has(link(Job.name(job)))
    |> click(button("Manage"))
    |> click(button("View Client"))
    |> assert_url_contains("clients/#{job.client_id}")
    |> assert_has(testid("client-details"))
  end

  feature "visits job gallery", %{
    session: session,
    job: job,
    lead: lead
  } do
    session
    |> click(@leads_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(lead.client.name))
    |> assert_has(link(Job.name(lead)))
    |> click(button("Manage"))
    |> click(button("Go to galleries"))
    |> assert_url_contains("leads/#{lead.id}")
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(job.client.name))
    |> assert_has(link(Job.name(job)))
    |> click(button("Manage"))
    |> click(button("Go to galleries"))
    |> assert_url_contains("jobs/#{job.id}")
  end

  feature "sends job email", %{
    session: session,
    job: job,
    lead: lead
  } do
    session
    |> click(@leads_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(lead.client.name))
    |> assert_has(link(Job.name(lead)))
    |> click(button("Manage"))
    |> click(button("Send email"))
    |> refute_has(select("Select email preset"))
    |> fill_in(text_field("Subject line"), with: "Here is what I propose")
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> click(button("Send"))
    |> assert_text("Thank you! Your message has been sent. We’ll be in touch with you soon.")
    |> click(button("Close"))
    |> click(link("Picsello"))
    |> click(@jobs_card)
    |> assert_has(testid("job-row", count: 1))
    |> assert_has(link(job.client.name))
    |> assert_has(link(Job.name(job)))
    |> click(button("Manage"))
    |> click(button("Send email"))
    |> refute_has(select("Select email preset"))
    |> fill_in(text_field("Subject line"), with: "Here is what I propose")
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> click(button("Send"))
    |> assert_text("Thank you! Your message has been sent. We’ll be in touch with you soon.")
    |> click(button("Close"))
  end
end
