defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller
  alias Picsello.{Repo, ClientMessageRecipient, ClientMessage, Messages, Client, Job}

  def parse(conn, params) do
    %{"envelope" => envelope} = params
    to_email = envelope |> Jason.decode!() |> Map.get("to")
    to_email = if is_list(to_email), do: to_email |> hd, else: to_email
    [token | _] = to_email |> String.split("@")

    {initail_obj, required_fields} =
      case Messages.find_by_token(token) do
        %Client{id: id} ->
          {%{client_id: id}, []}

        %Job{id: id} ->
          {%{job_id: id}, [:job_id]}

        _ -> {nil, []}
      end

    body_text = Map.get(params, "text")

    changeset =
      Map.merge(
        %{
          body_text:
            if(body_text, do: ElixirEmailReplyParser.parse_reply(body_text), else: body_text),
          body_html: Map.get(params, "html", ""),
          subject: Map.get(params, "subject", nil),
          outbound: false
        },
        initail_obj
      )
      |> ClientMessage.create_inbound_changeset(required_fields)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:message, changeset)
    |> Ecto.Multi.merge(fn %{message: %{id: message_id}} ->
      multi = Ecto.Multi.new()

      case initail_obj do
        %{client_id: client_id} ->
          params =
            ClientMessageRecipient.create_changeset(%{
              client_id: client_id,
              client_message_id: message_id,
              recipient_type: :to
            })

          multi |> Ecto.Multi.insert(:message_recipient, params)

        _ ->
          multi
      end
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{message: message}} ->
        Messages.notify_inbound_message(message, PicselloWeb.Helpers)

      {:error, reason} ->
        reason
    end)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
