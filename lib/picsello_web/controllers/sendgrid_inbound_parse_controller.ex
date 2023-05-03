defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, ClientMessage, Messages, Client, Job}

  def parse(conn, params) do
    %{"envelope" => envelope} = params
    to_email = envelope |> Jason.decode!() |> Map.get("to") |> hd
    [token | _] = to_email |> String.split("@")

    {initail_obj, required_fields} =
      case Messages.find_by_token(token) do
        %Client{id: id} ->
          {%{client_id: id}, [:client_id]}

        %Job{id: id} ->
          {%{job_id: id}, [:job_id]}

        _ ->
          {nil, []}
      end

    if initail_obj do
      Map.merge(
        %{
          body_text: Map.get(params, "text", "") |> ElixirEmailReplyParser.parse_reply(),
          body_html: Map.get(params, "html", ""),
          subject: Map.get(params, "subject")
        },
        initail_obj
      )
      |> ClientMessage.create_inbound_changeset(required_fields)
      |> Repo.insert!()
      |> Messages.notify_inbound_message(PicselloWeb.Helpers)
    end

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
