defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, Job, ClientMessage, Messages}

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

    Messages.notify_inbound_message(message, PicselloWeb.Helpers)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
