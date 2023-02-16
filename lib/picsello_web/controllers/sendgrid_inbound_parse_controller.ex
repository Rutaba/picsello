defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, ClientMessage, Messages, Client, Job}

  def parse(conn, params) do
    %{"envelope" => envelope} = params
    to_email = envelope |> Jason.decode!() |> Map.get("to") |> hd
    [token | _] = to_email |> String.split("@")

    initail_obj =
      case Messages.find_by_token(token) do
        %Client{id: id} ->
          %{client_id: id}

        %Job{id: id} ->
          %{job_id: id}
      end

    message =
      Map.merge(
        %{
          body_text: Map.get(params, "text", "") |> ElixirEmailReplyParser.parse_reply(),
          body_html: Map.get(params, "html", ""),
          subject: Map.get(params, "subject", nil)
        },
        initail_obj
      )
      |> ClientMessage.create_inbound_changeset()
      |> Repo.insert!()

    Messages.notify_inbound_message(message, PicselloWeb.Helpers)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
