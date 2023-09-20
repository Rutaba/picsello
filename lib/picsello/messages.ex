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
    Notifiers.UserNotifier,
    Accounts.User,
    Organization
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
    %{client_message_recipients: [%{client: %{organization: org}} | _]} =
      Repo.preload(message, client_message_recipients: [client: :organization])

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "inbound_messages:#{org.id}",
      {:inbound_messages, message}
    )

    if Map.get(message, :job_id) do
      UserNotifier.deliver_new_inbound_message_email(message, helpers)
    end
  end

  def token(%Job{} = job), do: token(job, "JOB_ID")
  def token(%Organization{} = org), do: token(org, "ORGANIZATION_ID")

  def token(%{id: id, inserted_at: inserted_at}, key) do
    signed_at =
      case inserted_at do
        %DateTime{} ->
          DateTime.to_unix(inserted_at)

        %NaiveDateTime{} ->
          inserted_at
          |> DateTime.from_naive("Etc/UTC")
          |> elem(1)
          |> DateTime.to_unix()
      end

    Phoenix.Token.sign(PicselloWeb.Endpoint, key, id, signed_at: signed_at)
  end

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
        if job, do: job, else: find_by_token(token, "ORGANIZATION_ID")

      _ ->
        find_by_token(token, "ORGANIZATION_ID")
    end
  end

  def find_by_token("" <> token, key) do
    result = Phoenix.Token.verify(PicselloWeb.Endpoint, key, token, max_age: :infinity)

    Logger.warning(
      "[Token] find_by_token result {#{Tuple.to_list(result) |> List.first()}, #{Tuple.to_list(result) |> List.last()}}"
    )

    case result do
      {:ok, id} -> Repo.get(Organization, id)
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

  def job_threads(%User{} = user, opts \\ []) do
    unread? = Keyword.get(opts, :unread?, false)

    job_query = Job.for_user(user)
    preload_query = from(c in ClientMessageRecipient, where: c.recipient_type == :to)

    from(message in ClientMessage,
      join: jobs in subquery(job_query),
      on: jobs.id == message.job_id,
      distinct: message.job_id,
      where: is_nil(message.deleted_at) and not is_nil(message.job_id),
      order_by: [desc: message.inserted_at]
    )
    |> then(fn
      query when unread? == true -> from q in query, where: is_nil(q.read_at)
      query -> query
    end)
    |> Repo.all()
    |> Repo.preload(job: [:client], client_message_recipients: {preload_query, [:client]})
  end

  def client_threads(%User{} = user, opts \\ []) do
    unread? = Keyword.get(opts, :unread?, false)

    from(client in Client,
      as: :client,
      join: message_receipent in ClientMessageRecipient,
      on: client.id == message_receipent.client_id,
      join: message in ClientMessage,
      as: :client_message,
      on: message_receipent.client_message_id == message.id,
      inner_lateral_join:
        top_one in subquery(
          from cmr in ClientMessageRecipient,
            join: cm in assoc(cmr, :client_message),
            where: cmr.client_id == parent_as(:client).id,
            where: is_nil(cm.job_id) and is_nil(cm.deleted_at),
            order_by: [desc: cm.inserted_at],
            limit: 1,
            select: [:client_id]
        ),
      on: top_one.client_id == client.id,
      distinct: client.id,
      where: client.organization_id == ^user.organization_id,
      where: is_nil(message.job_id) and is_nil(message.deleted_at),
      order_by: [desc: message.inserted_at],
      preload: [client_message_recipients: {message_receipent, :client_message}]
    )
    |> then(fn
      query when unread? == true -> from([client_message: cm] in query, where: is_nil(cm.read_at))
      query -> query
    end)
    |> Repo.all()
    |> Enum.reduce([], fn %{
                            client_message_recipients: [
                              %{client_message: client_message} = recipient
                            ]
                          } = client,
                          acc ->
      client = Map.delete(client, :client_message_recipients)
      recipient = recipient |> Map.delete(:client_message) |> Map.put(:client, client)

      acc ++ [Map.merge(client_message, %{client_message_recipients: [recipient], job: nil})]
    end)
  end

  def for_job(job) do
    from(message in ClientMessage,
      where: message.job_id == ^job.id and is_nil(message.deleted_at),
      order_by: [asc: message.inserted_at],
      preload: [client_message_recipients: [:client], job: [:client]]
    )
    |> Repo.all()
  end

  def for_client(client) do
    preload_query =
      from cmr in ClientMessageRecipient, where: cmr.client_id == ^client.id, preload: :client

    from(message in ClientMessage,
      join: crm in assoc(message, :client_message_recipients),
      where:
        crm.client_id == ^client.id and is_nil(message.deleted_at) and is_nil(message.job_id),
      distinct: message.id,
      order_by: [asc: message.inserted_at],
      preload: [client_message_recipients: ^preload_query]
    )
    |> Repo.all()
  end

  def unread_messages(%User{organization_id: organization_id} = user) do
    job_ids =
      user
      |> Job.for_user()
      |> ClientMessage.unread_messages()
      |> distinct([m], m.id)
      |> order_by([m], asc: m.inserted_at)
      |> select([m], m.job_id)
      |> Repo.all()

    client_ids =
      user
      |> client_threads(unread?: true)
      |> Enum.map(&hd(&1.client_message_recipients).client_id)

    message_ids =
      from(m in ClientMessage,
        left_join: cmr in assoc(m, :client_message_recipients),
        left_join: c in assoc(cmr, :client),
        where: c.organization_id == ^organization_id and is_nil(m.read_at),
        select: m.id
      )
      |> Repo.all()

    {job_ids, client_ids, message_ids}
  end

  def update_all(client_id, :client, column) do
    from(m in ClientMessage,
      join: cmr in assoc(m, :client_message_recipients),
      where: is_nil(m.job_id) and cmr.client_id == ^client_id,
      where: is_nil(field(m, ^column))
    )
    |> update_field(column)
  end

  def update_all(job_id, :job, column) do
    from(m in ClientMessage,
      where: m.job_id == ^job_id,
      where: is_nil(field(m, ^column))
    )
    |> update_field(column)
  end

  defp update_field(query, column),
    do:
      query |> Repo.update_all(set: [{column, DateTime.utc_now() |> DateTime.truncate(:second)}])
end
