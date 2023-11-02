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
    Organization,
    Clients,
    Campaign,
    CampaignClient
  }

  alias Ecto.Multi

  def parse(conn, params) do
    %{"envelope" => envelope} = params
    %{"to" => to_email, "from" => from} = envelope |> Jason.decode!() |> Map.take(["to", "from"])

    to_email = if is_list(to_email), do: to_email |> hd, else: to_email
    [token | _] = to_email |> String.split("@")

    case Messages.find_by_token(token) do
      %Organization{} = org ->
        client = Clients.client_by_email(org.id, from)

        process_message(params, {%{client_id: client.id}, [], client.id})

      %Job{id: id} = job ->
        %{client: %{organization: org}} = Repo.preload(job, client: :organization)
        client = Clients.client_by_email(org.id, from)

        process_message(params, {%{job_id: id}, [:job_id], client.id})

      %Campaign{} = campaign ->
        process_message(params, from, campaign)

      _ ->
        :ok
    end

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  defp process_message(params, {initail_obj, required_fields, client_id}) do
    body_text = Map.get(params, "text")

    subject = Map.get(params, "subject")

    changeset =
      Map.merge(
        %{
          body_text:
            if(body_text, do: ElixirEmailReplyParser.parse_reply(body_text), else: body_text),
          body_html: Map.get(params, "html", ""),
          subject: (subject == "" && "Re: No subject") || subject,
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
      |> maybe_upload_attachments(message_id, params, :message)
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{message: message}} ->
        Messages.notify_inbound_message(message, PicselloWeb.Helpers)

      {:error, reason} ->
        reason
    end)
  end

  defp process_message(params, from, %{organization_id: organization_id} = campaign) do
    body_text = Map.get(params, "text")
    client = Clients.client_by_email(organization_id, from)
    subject = Map.get(params, "subject")

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :campaign,
      Campaign.changeset(%{
        body_text: (body_text && ElixirEmailReplyParser.parse_reply(body_text)) || body_text,
        body_html: Map.get(params, "html", ""),
        subject: (subject == "" && "Re: No subject") || subject,
        segment_type: "client_reply",
        parent_id: campaign.id,
        organization_id: organization_id
      })
    )
    |> Ecto.Multi.insert(:campaign_client, fn %{campaign: %{id: campaign_id}} ->
      CampaignClient.changeset(%{client_id: client.id, campaign_id: campaign_id})
    end)
    |> Multi.merge(fn %{campaign: %{id: campaign_id}} ->
      Multi.new()
      |> maybe_upload_attachments(campaign_id, params, :campaign)
    end)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{campaign: campaign, campaign_client: campaign_client}} ->
        campaign
        |> Map.put(:campaign_clients, [campaign_client])
        |> then(&Messages.notify_inbound_campaign_message(&1))

      {:error, reason} ->
        reason
    end)
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
  def maybe_upload_attachments(multi, id, params, type) do
    case maybe_has_attachments?(params) do
      true ->
        attachments =
          params
          |> get_all_attachments()
          |> Enum.map(&upload_attachment(&1, id, type))

        Multi.insert_all(multi, :attachments, ClientMessageAttachment, attachments)

      _ ->
        multi
    end
  end

  # Upload to google cloud storage
  # return path, message_id, and filename
  defp upload_attachment(
         %{filename: filename, path: path} = _attachment,
         id,
         type
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    upload_path =
      Path.join([
        "inbox-attachments",
        to_string(type),
        from_date(now, :year),
        from_date(now, :month),
        from_date(now, :day),
        to_string(id),
        "#{DateTime.to_unix(now)}_#{filename}"
      ])

    file = File.read!(path)
    {:ok, _object} = PhotoStorage.insert(upload_path, file)

    %{
      name: filename,
      url: upload_path,
      inserted_at: now,
      updated_at: now
    }
    |> then(fn
      object when type == :message -> Map.put(object, :client_message_id, id)
      object when type == :campaign -> Map.put(object, :campaign_id, id)
    end)
  end

  # Need this step to pull the keys from "attachment-info"
  # and use them to get the actual attachments from plug
  defp get_all_attachments(params) do
    params
    |> Map.get("attachment-info")
    |> Jason.decode!()
    |> Enum.map(fn {key, _} -> Map.get(params, key) end)
  end

  defp maybe_has_attachments?(%{"attachment-info" => _}), do: true
  defp maybe_has_attachments?(_), do: false

  @periods ~w(day month year)a
  defp from_date(datetime, period) when period in @periods,
    do: datetime |> Map.get(period) |> to_string()
end
