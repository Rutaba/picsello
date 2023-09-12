defmodule Picsello.Messages do
  @moduledoc """
  The Messages context.
  """

  require Logger
  import Ecto.Query, warn: false

  alias Ecto.Changeset

  alias Picsello.{
    Job,
    Client,
    Clients,
    Repo,
    ClientMessage,
    ClientMessageRecipient,
    Notifiers.UserNotifier
  }

  def add_message_to_job(
        %Changeset{} = changeset,
        %Job{id: id} = job,
        recipients_list,
        user
      ) do
    recipients = get_recipient_attrs(recipients_list, user, job)

    changeset
    |> Changeset.put_change(:job_id, id)
    |> save_message(recipients)
  end

  def add_message_to_client(%Changeset{} = changeset, recipients_list, user) do
    recipients = get_recipient_attrs(recipients_list, user)

    changeset
    |> save_message(recipients)
  end

  def insert_scheduled_message!(params, %Job{} = job) do
    params
    |> scheduled_message_changeset(job)
    |> Repo.insert!()
  end

  def scheduled_message_changeset(params, %Job{} = job) do
    params
    |> ClientMessage.create_outbound_changeset()
    |> Ecto.Changeset.put_change(:job_id, job.id)
    |> Ecto.Changeset.put_change(:scheduled, true)
    |> Ecto.Changeset.put_assoc(:client_message_recipients, [
      %{client_id: job.client_id, recipient_type: String.to_atom("to")}
    ])
  end

  def notify_inbound_message(%ClientMessage{} = message, helpers) do
    if Map.get(message, :job_id) do
      job = message |> Repo.preload(job: :client) |> Map.get(:job)
      UserNotifier.deliver_new_inbound_message_email(message, helpers)

      Phoenix.PubSub.broadcast(
        Picsello.PubSub,
        "inbound_messages:#{job.client.organization_id}",
        {:inbound_messages, message}
      )
    end
  end

  def token(%Job{} = job), do: token(job, "JOB_ID")
  def token(%Client{} = client), do: token(client, "CLIENT_ID")

  def token(%{id: id, inserted_at: inserted_at}, key),
    do:
      PicselloWeb.Endpoint
      |> Phoenix.Token.sign(key, id, signed_at: DateTime.to_unix(inserted_at))

  def email_address(record) do
    domain = Application.get_env(:picsello, Picsello.Mailer) |> Keyword.get(:reply_to_domain)
    [token(record), domain] |> Enum.join("@")
  end

  def find_by_token("" <> token) do
    result = Phoenix.Token.verify(PicselloWeb.Endpoint, "JOB_ID", token, max_age: :infinity)

    Logger.warning(
      "[Token] find_by_token result {#{Tuple.to_list(result) |> List.first()}, #{Tuple.to_list(result) |> List.last()}}"
    )

    case result do
      {:ok, id} ->
        job = Repo.get(Job, id)
        if job, do: job, else: find_by_token(token, "CLIENT_ID")

      _ ->
        find_by_token(token, "CLIENT_ID")
    end
  end

  def find_by_token("" <> token, key) do
    result = Phoenix.Token.verify(PicselloWeb.Endpoint, key, token, max_age: :infinity)

    Logger.warning(
      "[Token] find_by_token result {#{Tuple.to_list(result) |> List.first()}, #{Tuple.to_list(result) |> List.last()}}"
    )

    case result do
      {:ok, id} -> Repo.get(Client, id)
      _ -> nil
    end
  end

  defp save_message(changeset, recipients) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:client_message, changeset)
    |> Ecto.Multi.insert_all(
      :client_message_recipients,
      ClientMessageRecipient,
      fn %{client_message: client_message} ->
        recipients
        |> Enum.map(fn attrs ->
          attrs
          |> Map.put(:client_message_id, client_message.id)
        end)
      end
    )
  end

  defp get_recipient_attrs(recipients_list, user, job \\ nil) do
    recipients_list
    |> Enum.map(fn {type, recipients} ->
      if is_list(recipients),
        do:
          recipients
          |> Enum.map(fn recipient ->
            get_attrs(recipient, type, user, job)
          end),
        else: get_attrs(recipients, type, user, job)
    end)
    |> List.flatten()
  end

  defp get_attrs(email, type, %{organization_id: organization_id}, job) do
    client = Clients.client_by_email(organization_id, email)

    client =
      case client do
        nil ->
          insert_client_multi(email, organization_id, job)

        %{id: id, archived_at: nil} ->
          {:ok, client} = Clients.unarchive_client(id)
          client

        _ ->
          client
      end

    %{
      client_id: client.id,
      recipient_type: String.to_atom(type),
      inserted_at: now(),
      updated_at: now()
    }
  end

  defp insert_client_multi(email, organization_id, job) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_client, fn _ ->
      Clients.new_client_changeset(
        %{"name" => String.split(email, "@") |> List.first(), "email" => email},
        organization_id
      )
    end)
    |> Ecto.Multi.insert(:insert_tag, fn %{insert_client: %{id: client_id}} ->
      name = get_tag_name(job)

      Picsello.ClientTag.create_changeset(%{
        "name" => name,
        "client_id" => client_id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{insert_client: client}} ->
        client
    end
  end

  defp get_tag_name(nil), do: "Associated to client"

  defp get_tag_name(job) do
    job = Repo.preload(job, :client)
    name = if job.job_name, do: job.job_name, else: "#{job.client.name} #{job.type}"

    "Associated to lead/job \"#{name}\""
  end

  defp now(), do: DateTime.utc_now() |> DateTime.truncate(:second)

  def get_emails(recipients, type \\ "to") do
    emails = Map.get(recipients, type)
    if is_list(emails), do: Enum.join(emails, "; "), else: emails
  end
end
