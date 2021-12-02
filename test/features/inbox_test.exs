defmodule Picsello.InboxTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user, type: "wedding")

    insert(:client_message,
      job: lead,
      body_text: "lead message 1",
      inserted_at: ~N[2021-10-10 08:00:00]
    )

    job = insert(:lead, user: user, type: "newborn") |> promote_to_job()

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
    |> assert_text("Mary Jane Newborn")
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
end
