defmodule Picsello.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Picsello.{Job, Client, Repo, ClientMessage, Notifiers.UserNotifier}

  def add_message_to_job(%Changeset{} = changeset, %Job{id: id, client_id: client_id}) do
    changeset
    |> Changeset.put_change(:job_id, id)
    |> Changeset.put_change(:client_id, client_id)
    |> Repo.insert()
  end

  def add_message_to_client(%Changeset{} = changeset) do
    changeset
    |> Repo.insert()
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
    |> Ecto.Changeset.put_change(:client_id, job.client_id)
    |> Ecto.Changeset.put_change(:scheduled, true)
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
    case Phoenix.Token.verify(PicselloWeb.Endpoint, "JOB_ID", token, max_age: :infinity) do
      {:ok, id} -> Repo.get(Job, id)
      _ -> find_by_token(token, "CLIENT_ID")
    end
  end

  def find_by_token("" <> token, key) do
    case Phoenix.Token.verify(PicselloWeb.Endpoint, key, token, max_age: :infinity) do
      {:ok, id} -> Repo.get(Client, id)
      _ -> nil
    end
  end
end
