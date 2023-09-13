defmodule PicselloWeb.SendgridInboundParseController do
  use PicselloWeb, :controller

  alias Picsello.{
    Repo,
    ClientMessageAttachment,
    ClientMessageRecipient,
    ClientMessage,
    Messages,
    Job,
    Galleries.Workers.PhotoStorage,
    Organization
  }

  alias Ecto.Multi

  def parse(conn, params) do
    %{"envelope" => envelope} = params
    %{"to" => to_email, "from" => from} = envelope |> Jason.decode!() |> Map.take(["to", "from"])

    to_email = if is_list(to_email), do: to_email |> hd, else: to_email
    [token | _] = to_email |> String.split("@")

    {initail_obj, required_fields, client_id} =
      case Messages.find_by_token(token) do
        %Organization{} = org ->
          client = Clients.client_by_email(org.id, from)

          {%{client_id: client.id}, [], client.id}

        %Job{id: id} = job ->
          %{client: %{organization: org}} = Repo.preload(job, client: :organization)
          client = Clients.client_by_email(org.id, from)

          {%{job_id: id}, [:job_id], client.id}

        _ ->
          {nil, [], nil}
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
      |> Ecto.Multi.insert(:recipient, fn %{message: %{id: message_id}} ->
        ClientMessageRecipient.create_changeset(%{
          client_id: client_id,
          client_message_id: message_id,
          recipient_type: :to
        })
      end)
      |> Multi.merge(fn %{message: %{id: message_id}} ->
        Multi.new()
        |> maybe_upload_attachments(message_id, params)
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
  Checks if the returned map has the key "attachment-info" and uploads the docs to google cloud storage

  returns a list of maps with the keys: client_message_id, name, and url

  ## Examples

      iex> maybe_upload_attachments(params)
      multi

      iex> maybe_has_attachments?(%{"subject" => "something"})
      multi

  """
  def maybe_upload_attachments(multi, message_id, params) do
    case maybe_has_attachments?(params) do
      true ->
        attachments =
          params
          |> get_all_attachments()
          |> Enum.map(&upload_attachment(&1, message_id))

        Multi.insert_all(multi, :attachments, ClientMessageAttachment, attachments)

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
        get_date(now, :year),
        get_date(now, :month),
        get_date(now, :day),
        Integer.to_string(message_id),
        "#{now |> DateTime.to_unix()}_#{filename}"
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
    |> Map.get("attachment-info")
    |> Jason.decode!()
    |> Enum.map(fn {key, _} ->
      Map.get(params, key)
    end)
  end

  defp maybe_has_attachments?(%{"attachment-info" => _}), do: true
  defp maybe_has_attachments?(_), do: false

  defp get_date(datetime, :year), do: Integer.to_string(datetime.year)
  defp get_date(datetime, :month), do: Integer.to_string(datetime.month)
  defp get_date(datetime, :day), do: Integer.to_string(datetime.day)
end
