defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, Job, ClientMessage, Notifiers.UserNotifier}

  def parse(conn, params) do
    %{"text" => text, "html" => body_html, "envelope" => envelope, "subject" => subject} = params
    to_email = envelope |> Jason.decode!() |> Map.get("to") |> hd
    [token | _] = to_email |> String.split("@")

    job = Job.find_by_token(token) |> Repo.preload(:client)
    body_text = ElixirEmailReplyParser.parse_reply(text)

    message =
      %{body_text: body_text, body_html: body_html, subject: subject, job_id: job.id}
      |> ClientMessage.create_inbound_changeset()
      |> Repo.insert!()

    UserNotifier.deliver_new_inbound_message_email(message)

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "inbound_messages:#{job.client.organization_id}",
      {:inbound_messages, message}
    )

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
