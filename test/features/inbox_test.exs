defmodule Picsello.InboxTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    lead = insert(:lead, user: user, type: "wedding")
    job = insert(:lead, user: user, type: "family") |> promote_to_job()

    client_message =
      insert(:client_message,
        outbound: false,
        job: lead,
        body_text: "lead message 1",
        inserted_at: ~N[2021-10-10 08:00:00]
      )

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

    client_message_3 =
      insert(:client_message,
        outbound: true,
        body_text: "client type  message ",
        inserted_at: ~N[2021-10-12 08:00:00]
      )

    campaign = insert(:campaign, user: user, body_html: "<p>body</p>")
    insert(:campaign_client, campaign: campaign, client: job.client)

    insert(:client_message_recipient, client_message: client_message, client_id: lead.client_id)
    insert(:client_message_recipient, client_message: client_message_1, client_id: job.client_id)
    insert(:client_message_recipient, client_message: client_message_2, client_id: job.client_id)
    insert(:client_message_recipient, client_message: client_message_3, client_id: job.client_id)

    [job: job, lead: lead, client: lead.client]
  end

  feature "user views all type of  messages in inbox", %{session: session} do
    session
    |> click(button("View inbox"))
    |> assert_has(testid("thread-card", count: 4))
    |> assert_text("No message selected")
    |> click(testid("thread-card", count: 4, at: 1))
    |> click(css("[phx-click='collapse-section']", at: 0))
    |> assert_text("here is what i propose")
  end

  feature "user views job/leads  messages in inbox", %{session: session} do
    session
    |> click(button("View inbox"))
    |> assert_has(testid("thread-card", count: 4))
    |> assert_text("No message selected")
    |> click(button("Jobs/Leads"))
    |> assert_has(testid("thread-card", count: 2))
  end

  feature "user views marketing  messages in inbox", %{session: session} do
    session
    |> click(button("View inbox"))
    |> assert_has(testid("thread-card", count: 4))
    |> assert_text("No message selected")
    |> click(button("Marketing"))
    |> assert_has(testid("thread-card", count: 1))
  end

  feature "user views clients  messages in inbox", %{session: session} do
    session
    |> click(button("View inbox"))
    |> assert_has(testid("thread-card", count: 4))
    |> assert_text("No message selected")
    |> click(button("Clients"))
    |> assert_has(testid("thread-card", count: 1))
  end

  feature "user views thread", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 1))
    |> assert_has(testid("thread-message", count: 1))

    session
    |> find(testid("thread-message", count: 1, at: 0))
    |> assert_text("here is what i propose")
    |> assert_text("client type message")
  end

  feature "user receives message", %{session: session, job: job, client: client} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 1))
    |> assert_has(testid("thread-message", count: 1))

    token = Picsello.Messages.token(job)

    session
    |> post(
      "/sendgrid/inbound-parse",
      %{
        "text" => "client response",
        "html" => "<p>client response</p>",
        "subject" => "Re: subject",
        "envelope" =>
          Jason.encode!(%{"to" => "#{token}@test-inbox.picsello.com", "from" => client.email})
      }
      |> URI.encode_query(),
      [{"Content-Type", "application/x-www-form-urlencoded"}]
    )

    session
    |> assert_has(testid("new-badge", count: 1))
  end

  feature "user replies to message", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 1))
    |> scroll_to_bottom()
    |> click(button("Reply"))
    |> assert_has(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> fill_in_quill("This is my response")
    |> within_modal(fn modal ->
      modal
      |> fill_in(text_field("Subject line"), with: "My subject")
      |> wait_for_enabled_submit_button
    end)
    |> click(button("Send Email"))
    |> assert_has(testid("thread-message", count: 2))

    session
    |> find(testid("thread-message", count: 2, at: 1))
    |> assert_text("This is my response")
  end

  feature "user deletes thread", %{session: session} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 1))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> assert_has(testid("thread-card", count: 3))
    |> click(testid("thread-card", count: 3, at: 1))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> click(testid("thread-card", count: 2, at: 1))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> assert_has(testid("thread-card", count: 1))
    |> click(testid("thread-card", count: 1, at: 0))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> assert_has(testid("thread-card", count: 0))
    |> assert_text("You don’t have any new messages.")
  end

  feature "user goes to lead page from message", %{session: session, lead: lead} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 3))
    |> assert_has(
      css("a[href*='#{Routes.job_path(PicselloWeb.Endpoint, :leads, lead.id)}']",
        text: "View lead"
      )
    )
  end

  feature "user goes to job page from message", %{session: session, job: job} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 2))
    |> assert_has(
      css("a[href*='#{Routes.job_path(PicselloWeb.Endpoint, :jobs, job.id)}']",
        text: "View job"
      )
    )
  end

  feature "archive chat", %{session: session, job: job} do
    session
    |> click(button("View inbox"))
    |> click(testid("thread-card", count: 4, at: 1))
    |> scroll_to_bottom()
    |> click(button("Reply"))
    |> assert_has(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> fill_in_quill("This is my response")
    |> within_modal(fn modal ->
      modal
      |> fill_in(text_field("Subject line"), with: "My subject")
      |> wait_for_enabled_submit_button
    end)
    |> click(button("Send Email"))
    |> assert_has(testid("thread-message", count: 2))
    |> assert_text("This is my response")
    |> scroll_into_view(testid("inbox-title"))
    |> click(button("Delete"))
    |> click(button("Yes, delete"))
    |> visit("/jobs/#{job.id}")
    |> click(button("View inbox"))
    |> assert_has(testid("thread-message", count: 0))
  end
end
