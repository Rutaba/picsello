defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller

  alias Picsello.{
    Repo,
    ClientMessageAttachment,
    ClientMessageRecipient,
    ClientMessage,
    Messages,
    Client,
    Job,
    Galleries.Workers.PhotoStorage
  }

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

        _ ->
          {nil, []}
      end

    body_text = Map.get(params, "text")

    if initail_obj do
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
      |> Ecto.Multi.merge(fn %{message: %{id: message_id}} ->
        Ecto.Multi.new()
        |> maybe_upload_attachments?(message_id, params)
      end)
      |> Repo.transaction()
      |> then(fn
        {:ok, %{message: message}} ->
          Messages.notify_inbound_message(message, PicselloWeb.Helpers)

        {:error, reason} ->
          reason
      end)
    end

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  @doc """
  Checks if the returned map has the key "attachment-info"

  ## Examples

      iex> maybe_has_attachments?(%{"attachment-info" => "something"})
      true

      iex> maybe_has_attachments?(%{"subject" => "something"})
      false

  """
  def maybe_has_attachments?(params) do
    case Map.get(params, "attachment-info", nil) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Checks if the returned map has the key "attachment-info" and uploads the docs to google cloud storage

  returns a list of maps with the keys: client_message_id, name, and url

  ## Examples

      iex> maybe_upload_attachments?(params)
      [
        %{
          client_message_id: 1,
          name: "some_name",
          url: "inbox-attachments/1/some_name",
          inserted_at: ~U[2020-01-01 00:00:00Z],
          updated_at: ~U[2020-01-01 00:00:00Z]
        }
      ]

      iex> maybe_has_attachments?(%{"subject" => "something"})
      nil

  """
  def maybe_upload_attachments?(multi, message_id, params) do
    case maybe_has_attachments?(params) do
      true ->
        attachments =
          get_all_attachments(params)
          |> Enum.map(&upload_attachment(&1, message_id))

        Ecto.Multi.insert_all(multi, :attachments, ClientMessageAttachment, attachments)

      _ ->
        multi
    end
  end

  # Upload to google cloud storage
  # return path, message_id, and filename
  defp upload_attachment(
         %{filename: filename, path: path} = _attachment,
         message_id
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    upload_path =
      Path.join([
        "inbox-attachments",
        Integer.to_string(message_id),
        filename
      ])

    file = File.read!(path)
    {:ok, _object} = PhotoStorage.insert(upload_path, file)

    %{
      client_message_id: message_id,
      name: filename,
      url: upload_path,
      inserted_at: now,
      updated_at: now
    }
  end

  # Need this step to pull the keys from "attachment-info"
  # and use them to get the actual attachments from plug
  defp get_all_attachments(params) do
    params
    |> Map.get("attachment-info", nil)
    |> Jason.decode!()
    |> Enum.map(fn {key, _} ->
      Map.get(params, key, nil)
    end)
  end
end
