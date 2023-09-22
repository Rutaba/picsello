defmodule Picsello.AddPaymentsToJobTest do
  @moduledoc false
  use Picsello.FeatureCase, async: false
  alias Picsello.Job

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    job =
      insert(:lead, %{
        user: user,
        type: "newborn",
        package: %{
          name: "My Package",
          description: "My custom description",
          shoot_count: 1,
          base_price: %Money{amount: 297_000, currency: "USD"}
        },
        client: %{name: "John"}
      })
      |> promote_to_job()

    [job: job, session: session, user: user]
  end

  feature "renders mark as paid modal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> within_modal(fn modal ->
      modal
      |> assert_has(css("#payment-modal", count: 1))
      |> assert_has(css("#close", count: 1))
      |> assert_has(css("#amount", count: 1))
      |> assert_has(css("#job-name", count: 1, text: Job.name(job)))
      |> assert_has(css("#add-payment", count: 1))
      |> assert_has(css("#done", count: 1))
    end)
  end

  feature "renders add payment modal", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> within_modal(fn modal ->
      modal
      |> assert_has(css("#add-payment", count: 1))
      |> click(css("#add-payment"))
      |> assert_has(css("#add-payment-form"))
    end)
  end

  feature "photog add offline payments", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> within_modal(fn modal ->
      modal
      |> assert_has(css("#add-payment", count: 1))
      |> click(css("#add-payment"))
      |> fill_in(text_field("add-payment-form_price"), with: "5")
      |> click(css("#mark_as_paid_payment"))
    end)
    |> fill_in(css(".numInput.cur-year"), with: "3022")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("January")))
    |> click(css("[aria-label='January 1, 3022']"))
    |> within_modal(fn modal ->
      modal
      |> click(button("Save"))
    end)
  end

  feature "modal renders number of payments addeed by photog", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> within_modal(fn modal ->
      modal
      |> assert_has(css("#add-payment", count: 1))
      |> click(css("#add-payment"))
      |> fill_in(text_field("add-payment-form_price"), with: "5")
      |> click(css("#mark_as_paid_payment"))
    end)
    |> fill_in(css(".numInput.cur-year"), with: "3022")
    |> find(css(".flatpickr-monthDropdown-months"), &click(&1, option("January")))
    |> click(css("[aria-label='January 1, 3022']"))
    |> within_modal(fn modal ->
      modal
      |> click(button("Save"))
      |> assert_has(css("#payments", count: 1, text: "Payment 1"))
      |> assert_has(css("#offline-amount", count: 1, text: "$5.00"))
    end)
  end

  feature "send email reminder to client", %{session: session, job: job} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> click(button("Send reminder email"))
    |> within_modal(fn modal ->
      modal
      |> assert_text("Send an email")
      |> click(button("Cancel"))
    end)
    |> click(css("#options"))
    |> click(button("Mark as paid"))
    |> click(button("Send reminder email"))
    |> within_modal(fn modal ->
      modal
      |> fill_in(css("#client_message_subject"), with: "Test subject")
      |> fill_in(css(".ql-editor"), with: "Test message")
      |> wait_for_enabled_submit_button()
      |> click(button("Send Email"))
    end)
  end
end
