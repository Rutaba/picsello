defmodule Picsello.PhotographerSendGeneralEmailTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, ClientMessage}

  @compose_email_button button("Send an email")
  @send_email_button button("Send Email")

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    [lead: insert(:lead, user: user)]
  end

  def compose_and_send_email(session, job) do
    session
    |> click(button("Manage"))
    |> click(@compose_email_button)
    |> assert_has(css("h1", text: "Send an email"))
    |> assert_text(job.client.email)
    |> fill_in(text_field("Subject line"), with: "Check this out")
    |> click(css("div[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> wait_for_enabled_submit_button()
    |> click(@send_email_button)
    |> assert_text("Email sent")

    assert_receive {:delivered_email, email}

    assert "Check this out" = email |> email_substitutions |> Map.get("subject")

    assert "This is 1st line\r\n2nd line\r\n" =
             email |> email_substitutions |> Map.get("body_text")

    assert "<p>This is 1st line</p><p>2nd line</p>" =
             email |> email_substitutions |> Map.get("body_html")

    assert [client_message] = Repo.all(ClientMessage)
    assert client_message.job_id == job.id
    assert client_message.proposal_id == nil

    session
  end

  feature "user sends booking proposal from lead", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> compose_and_send_email(lead)
  end

  feature "user sends email from job", %{session: session, lead: lead} do
    job = promote_to_job(lead)

    session
    |> visit("/jobs/#{job.id}")
    |> compose_and_send_email(job)
  end
end
