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
        %Job{id: id},
        recipients,
        user
      ) do
    changeset
    |> Changeset.put_change(:job_id, id)
    |> save_message(recipients, user)
  end

  def add_message_to_client(%Changeset{} = changeset, recipients, user) do
    changeset
    |> save_message(recipients, user)
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
    job = message |> Repo.preload(job: :client) |> Map.get(:job)
    UserNotifier.deliver_new_inbound_message_email(message, helpers)

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "inbound_messages:#{job.client.organization_id}",
      {:inbound_messages, message}
    )
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

    Logger.warn(
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

    Logger.warn(
      "[Token] find_by_token result {#{Tuple.to_list(result) |> List.first()}, #{Tuple.to_list(result) |> List.last()}}"
    )

    case result do
      {:ok, id} -> Repo.get(Client, id)
      _ -> nil
    end
  end

  defp save_message(changeset, recipients_list, user) do
    recipient_attrs = get_recipient_attrs(recipients_list, user)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:client_message, changeset)
    |> Ecto.Multi.insert_all(
      :client_message_recipients,
      ClientMessageRecipient,
      fn %{client_message: client_message} ->
        recipient_attrs
        |> Enum.map(fn attrs ->
          attrs
          |> Map.put(:client_message_id, client_message.id)
        end)
      end
    )
    |> Repo.transaction()
  end

  defp get_recipient_attrs(recipients_list, user),
    do:
      recipients_list
      |> Enum.map(fn {type, recipients} ->
        recipients
        |> Enum.map(fn recipient ->
          client = Clients.get_client(user, [email: recipient])

          %{
            client_id: client.id,
            recipient_type: String.to_atom(type),
            inserted_at: now(),
            updated_at: now()
          }
        end)
      end)
      |> List.flatten()

  defp now(), do: DateTime.utc_now() |> DateTime.truncate(:second)
end
