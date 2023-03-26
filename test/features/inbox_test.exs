defmodule Picsello.InboxTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user, type: "wedding")

    client_message =
      insert(:client_message,
        job: lead,
        body_text: "lead message 1",
        inserted_at: ~N[2021-10-10 08:00:00]
      )

    insert(:client_message_recipient, client_message: client_message, client_id: lead.client_id)

    job = insert(:lead, user: user, type: "family") |> promote_to_job()

    client_message_1 =
      insert(:client_message,
        job: job,
        body_text: "job message 1",
        outbound: false,
        inserted_at: ~N[2021-10-10 08:00:00]
      )

    client_message_2 =
      insert(:client_message,
        job: job,
        outbound: true,
        body_text: "job message 2",
        inserted_at: ~N[2021-10-11 08:00:00]
      )

    insert(:client_message_recipient, client_message: client_message_1, client_id: job.client_id)
    insert(:client_message_recipient, client_message: client_message_2, client_id: job.client_id)

    [job: job, lead: lead]
  end

  feature "user views inbox", %{session: session} do
    session
    |> click(button("View inbox"))
    |> assert_text("Select a message to your left")
    |> assert_has(testid("thread-card", count: 2))

    session
    |> find(testid("thread-card", count: 2, at: 0))
    |> assert_text("job message 2")
    |> assert_text("Mary Jane Family")
    |> assert_text("10/11/21")

    session
    |> find(testid("thread-card", count: 2, at: 1))
    |> assert_text("lead message 1")
    |> assert_text("Mary Jane Wedding")
    |> assert_text("10/10/21")
  end

  feature "user views thread", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> assert_has(testid("thread-message", count: 2))

    session
    |> find(testid("thread-message", count: 2, at: 0))
    |> assert_text("Mary Jane wrote")
    |> assert_text("job message 1")

    session
    |> find(testid("thread-message", count: 2, at: 1))
    |> assert_text("You wrote")
    |> assert_text("job message 2")
  end

  feature "user receives message", %{session: session, job: job} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> assert_has(testid("thread-message", count: 2))

    token = Picsello.Messages.token(job)

    session
    |> post(
      "/sendgrid/inbound-parse",
      %{
        "text" => "client response",
        "html" => "<p>client response</p>",
        "subject" => "Re: subject",
        "envelope" => Jason.encode!(%{"to" => "#{token}@test-inbox.picsello.com"})
      }
      |> URI.encode_query(),
      [{"Content-Type", "application/x-www-form-urlencoded"}]
    )

    session
    |> find(testid("thread-card", count: 2, at: 0))
    |> assert_has(testid("new-badge", count: 1))

    session
    |> assert_text("new message")
    |> find(testid("thread-message", count: 3, at: 2))
    |> assert_text("Mary Jane wrote")
    |> assert_text("client response")

    session
    |> click(testid("thread-card", count: 2, at: 1))
    |> find(testid("thread-card", count: 2, at: 0))
    |> assert_has(testid("new-badge", count: 0))
  end

  feature "user replies to message", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> scroll_to_bottom()
    |> click(button("Reply"))
    |> assert_has(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> fill_in_quill("This is my response")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Send Email"))
    |> assert_has(testid("thread-message", count: 3))

    session
    |> find(testid("thread-message", count: 3, at: 2))
    |> assert_text("This is my response")
  end

  feature "user deletes thread", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> assert_has(testid("thread-card", count: 1))
    |> click(testid("thread-card", count: 1, at: 0))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> assert_has(testid("thread-card", count: 0))
    |> assert_text("You don’t have any new messages")
  end

  feature "user goes to lead page from message", %{session: session, lead: lead} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 1))
    |> click(link("view lead"))
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id))
  end

  feature "user goes to job page from message", %{session: session, job: job} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> click(link("view job"))
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :jobs, job.id))
  end

  feature "archive chat", %{session: session, job: job} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> scroll_to_bottom()
    |> click(button("Reply"))
    |> assert_has(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> fill_in_quill("This is my response")
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Send Email"))
    |> assert_has(testid("thread-message", count: 3))
    |> assert_text("This is my response")
    |> scroll_into_view(testid("inbox-title"))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> visit("/jobs/#{job.id}")
    |> click(button("Go to inbox"))
    |> assert_has(testid("thread-message", count: 0))
  end
end
