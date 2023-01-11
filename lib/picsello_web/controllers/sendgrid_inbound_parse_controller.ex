defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, ClientMessage, Messages, Client, Job}

  def parse(conn, params) do
    %{"html" => body_html, "envelope" => envelope, "subject" => subject} = params
    to_email = envelope |> Jason.decode!() |> Map.get("to") |> hd
    [token | _] = to_email |> String.split("@")

    body_text = Map.get(params, "text", "") |> ElixirEmailReplyParser.parse_reply()

    initail_obj =
      case Messages.find_by_token(token) do
        %Client{id: id} ->
          %{client_id: id}

        %Job{id: id} ->
          %{job_id: id}
      end

    message =
      Map.merge(%{body_text: body_text, body_html: body_html, subject: subject}, initail_obj)
      |> ClientMessage.create_inbound_changeset()
      |> Repo.insert!()

    Messages.notify_inbound_message(message, PicselloWeb.Helpers)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
