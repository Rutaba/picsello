defmodule Picsello.InboxTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Job

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user, type: "wedding")

    insert(:client_message,
      job: lead,
      body_text: "lead message 1",
      inserted_at: ~N[2021-10-10 08:00:00]
    )

    job = insert(:lead, user: user, type: "family") |> promote_to_job()

    insert(:client_message,
      job: job,
      body_text: "job message 1",
      outbound: false,
      inserted_at: ~N[2021-10-10 08:00:00]
    )

    insert(:client_message,
      job: job,
      outbound: true,
      body_text: "job message 2",
      inserted_at: ~N[2021-10-11 08:00:00]
    )

    [job: job, lead: lead]
  end

  feature "user views inbox", %{session: session} do
    session
    |> click(testid("inbox-card"))
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
    |> click(testid("inbox-card"))
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
    |> click(testid("inbox-card"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> assert_has(testid("thread-message", count: 2))

    token = Job.token(job)

    session
    |> post(
      "/sendgrid/inbound-parse",
      %{
        "text" => "client response",
        "html" => "<p>client response</p>",
        "subject" => "Re: subject",
        "envelope" => Jason.encode!(%{"to" => ["#{token}@test-inbox.picsello.com"]})
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
    |> click(testid("inbox-card"))
    |> click(testid("thread-card", count: 2, at: 0))
    |> click(button("Reply"))
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is my response"])
    |> within_modal(&wait_for_enabled_submit_button/1)
    |> click(button("Send Email"))
    |> assert_has(testid("thread-message", count: 3))

    session
    |> find(testid("thread-message", count: 3, at: 2))
    |> assert_text("This is my response")
  end

  feature "user deletes thread", %{session: session} do
    session
    |> click(testid("inbox-card"))
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
end
