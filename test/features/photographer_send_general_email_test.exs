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

  def compose_email(session, job) do
    session
    |> click(button("Manage"))
    |> take_screenshot()
    |> click(link("Send an email"))
    |> assert_has(css("h1", text: "Send an email"))
    |> take_screenshot()
    |> assert_text(job.client.email)
    |> fill_in(text_field("Subject line"), with: "Check this out")
    |> assert_has(css(".ql-size"))
    |> assert_has(css(".ql-image"))
    |> click(css("div.ql-editor[data-placeholder='Compose message...']"))
    |> send_keys(["This is 1st line", :enter, "2nd line"])
    |> within_modal(&wait_for_enabled_submit_button/1)
  end

  def send_email(session, job) do
    session
    |> click(@send_email_button)
    |> assert_text("Email sent")

    assert_receive {:delivered_email, email}

    assert "Check this out" = email |> email_substitutions |> Map.get("subject")

    assert "<p>This is 1st line</p><p>2nd line</p>" =
             email |> email_substitutions |> Map.get("body")

    assert [client_message] = Repo.all(ClientMessage)
    assert client_message.job_id == job.id

    session
  end

  feature "user sends booking proposal from lead", %{session: session, lead: lead} do
    session
    |> visit("/leads/#{lead.id}")
    |> compose_email(lead)
    |> send_email(lead)
  end

  feature "user sends email from job", %{session: session, lead: lead} do
    job = promote_to_job(lead)

    session
    |> visit("/jobs/#{job.id}")
    |> compose_email(lead)
    |> send_email(lead)
  end

  feature "user attaches image on email", %{session: session, lead: lead} do
    job = promote_to_job(lead)
    %{port: port} = bypass = Bypass.open()

    upload_url = "http://localhost:#{port}"

    Picsello.PhotoStorageMock
    |> Mox.stub(:params_for_upload, fn options ->
      assert %{key: key, field: %{"content-type" => "image/jpeg"}} = Enum.into(options, %{})
      assert key =~ "favicon-128.jpg"
      %{url: upload_url, fields: %{key: "image.jpg"}}
    end)

    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("Access-Control-Allow-Origin", "*")
      |> Plug.Conn.resp(204, "")
    end)

    Bypass.expect_once(bypass, "GET", "/image.jpg", fn conn ->
      conn
      |> Plug.Conn.resp(200, "")
    end)

    session
    |> visit("/jobs/#{job.id}")
    |> compose_email(lead)
    |> attach_file(testid("quill-image-input", visible: false),
      path: "assets/static/favicon-128.png"
    )
    |> click(@send_email_button)
    |> assert_text("Email sent")

    assert_receive {:delivered_email, email}

    assert """
           <p>This is 1st line</p><p>2nd line</p><img src="http://localhost:#{port}/image.jpg" style="max-width: 100%; margin-left: auto; margin-right: auto;"><p><br></p><p><br></p>
           """ =~ email |> email_substitutions |> Map.get("body")
  end
end
