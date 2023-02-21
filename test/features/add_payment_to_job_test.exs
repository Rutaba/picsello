defmodule Picsello.AddPaymentsToJobTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job
  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    job =
      insert(:lead, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          base_price: 297_000
        },
        client: %{name: "John"}
      })
      |> promote_to_job()

    user
    |> Ecto.Changeset.change(%{allow_cash_payment: true})
    |> Picsello.Repo.update!()

    [job: job, session: session, user: user]
  end

  feature "renders mark as paid modal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> assert_has(css("#payment-modal", count: 1))
    |> assert_has(css("#close", count: 1))
    |> assert_has(css("#amount", count: 1))
    |> assert_has(css("#job-name", count: 1, text: Job.name(job)))
    |> assert_has(css("#add-payment", count: 1))
    |> assert_has(css("#done", count: 1))
  end

  feature "renders add payment modal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> assert_has(css("#add-payment", count: 1))
    |> click(css("#add-payment"))
    |> assert_has(css("#add-payment-form"))
  end

  feature "photog add offline payments", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> assert_has(css("#add-payment", count: 1))
    |> click(css("#add-payment"))
    |> fill_in(text_field("add-payment-form_price"), with: "5")
    |> click(css("#mark_as_paid_payment"))
    |> click(css("[data-action='next']"))
    |> click(css("[data-action='next']"))
    |> click(css("[data-date='12']"))
    |> click(button("Save"))
  end

  feature "modal renders number of payments addeed by photog", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> assert_has(css("#add-payment", count: 1))
    |> click(css("#add-payment"))
    |> fill_in(text_field("add-payment-form_price"), with: "5")
    |> click(css("#mark_as_paid_payment"))
    |> click(css("[data-action='next']"))
    |> click(css("[data-action='next']"))
    |> click(css("[data-date='12']"))
    |> click(button("Save"))
    |> assert_has(css("#payments", count: 1, text: "Payment 1"))
    |> assert_has(css("#offline-amount", count: 1, text: "$5.00"))
  end

  feature "send email reminder to client", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> click(button("Send reminder email"))
    |> assert_text("Send an email")
    |> click(button("Cancel"))
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> click(button("Send reminder email"))
    |> fill_in(css("#client_message_subject"), with: "Test subject")
    |> fill_in(css(".ql-editor"), with: "Test message")
    |> wait_for_enabled_submit_button()
    |> click(button("Send Email"))
  end
end
