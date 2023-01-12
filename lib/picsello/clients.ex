defmodule Picsello.Clients do
  @moduledoc "context module for clients"
  import Ecto.Query
  alias Picsello.{Repo, Client, ClientTag}

  def find_all_by(user: user) do
    from(c in Client,
      where: c.organization_id == ^user.organization_id and is_nil(c.archived_at),
      order_by: [asc: c.name, asc: c.email]
    )
    |> Repo.all()
  end

  def find_all_by(
        user: user,
        filters: %{sort_by: sort_by, sort_direction: sort_direction} = opts
      ) do
    from(client in Client,
      preload: [:tags, :jobs],
      left_join: jobs in assoc(client, :jobs),
      left_join: job_status in assoc(jobs, :job_status),
      where: client.organization_id == ^user.organization_id and is_nil(client.archived_at),
      where: ^filters_where(opts),
      where: ^filters_status(opts),
      group_by: client.id,
      order_by: ^filter_order_by(sort_by, sort_direction)
    )
  end

  def find_all_by_pagination(
        user: user,
        filters: opts,
        pagination: %{limit: limit, offset: offset}
      ) do
    query = find_all_by(user: user, filters: opts)

    from(c in query,
      limit: ^limit,
      offset: ^offset
    )
  end

  def new_client_changeset(attrs, organization_id) do
    attrs
    |> Map.put("organization_id", organization_id)
    |> Client.create_client_changeset()
  end

  def edit_client_changeset(client, attrs) do
    Client.edit_client_changeset(client, attrs)
  end

  def save_new_client(attrs, organization_id) do
    new_client_changeset(attrs, organization_id) |> Repo.insert()
  end

  def update_client(client, attrs) do
    edit_client_changeset(client, attrs) |> Repo.update()
  end

  def archive_client(id) do
    Repo.get(Client, id)
    |> Client.archive_changeset()
    |> Repo.update()
  end

  def get_client_tags(client_id) do
    from(tag in ClientTag,
      where: tag.client_id == ^client_id
    )
    |> Repo.all()
  end

  def delete_tag(client_id, name) do
    {:ok, _tag} =
      from(tag in ClientTag,
        where: tag.client_id == ^client_id and tag.name == ^name
      )
      |> Repo.one()
      |> Repo.delete()
  end

  def get_client(id, user) do
    from(c in Client,
      preload: [:tags, :jobs],
      where: c.id == ^id and c.organization_id == ^user.organization_id and is_nil(c.archived_at)
    )
    |> Repo.one()
  end

  def client_tags(client) do
    (Enum.map(client.jobs, & &1.type)
     |> Enum.uniq()) ++
      Enum.map(client.tags, & &1.name)
  end

  def get_client_orders_query(client_id) do
    from(c in Client,
      preload: [jobs: [gallery: [orders: [:intent, :digitals, :products]]]],
      where: c.id == ^client_id
    )
  end

  defp filters_where(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:type, "all"}, dynamic ->
        dynamic

      {:type, value}, dynamic ->
        dynamic(
          [client, jobs, job_status],
          ^dynamic and client.id == jobs.client_id and jobs.type == ^value
        )

      {:search_phrase, nil}, dynamic ->
        dynamic

      {:search_phrase, search_phrase}, dynamic ->
        search_phrase = "%#{search_phrase}%"

        dynamic(
          [client, jobs, job_status],
          ^dynamic and
            (ilike(client.name, ^search_phrase) or
               ilike(client.email, ^search_phrase) or
               ilike(client.phone, ^search_phrase))
        )

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filters_status(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:status, value}, dynamic ->
        case value do
          "past_jobs" ->
            filter_past_jobs(dynamic)

          "active_jobs" ->
            filter_active_jobs(dynamic)

          "leads" ->
            filter_leads(dynamic)

          _ ->
            dynamic
        end

      _any, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filter_past_jobs(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.id == jobs.client_id and
        not job_status.is_lead and
        job_status.current_status == :completed
    )
  end

  defp filter_active_jobs(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.id == jobs.client_id and
        not job_status.is_lead and
        job_status.current_status not in [:completed, :archived]
    )
  end

  defp filter_leads(dynamic) do
    dynamic(
      [client, jobs, job_status],
      ^dynamic and client.id == jobs.client_id and job_status.is_lead and
        is_nil(jobs.archived_at)
    )
  end

  # returned dynamic with join binding
  defp filter_order_by(:id, order),
    do: [{order, dynamic([client, jobs], count(field(jobs, :id)))}]

  defp filter_order_by(column, order) do
    [{order, dynamic([client], field(client, ^column))}]
  end
end
