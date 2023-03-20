defmodule Picsello.Jobs do
  @moduledoc "context module for jobs"
  alias Picsello.{
    Accounts.User,
    Repo,
    Client,
    Job,
    Shoot,
    PaymentSchedule,
    OrganizationJobType
  }

  import Ecto.Query

  def get_jobs(query, %{sort_by: sort_by, sort_direction: sort_direction} = opts) do
    shoots =
      from(s in Shoot,
        where: s.starts_at < ^current_datetime(),
        select: %{starts_at: s.starts_at, job_id: s.job_id},
        limit: 1
      )

    from(j in query,
      left_join: job_status in assoc(j, :job_status),
      left_join: shoots in subquery(shoots),
      left_join: package in assoc(j, :package),
      left_join: payment_schedules in assoc(j, :payment_schedules),
      where: ^filters_where(opts),
      where: ^filters_status(opts),
      order_by: ^filter_order_by(sort_by, sort_direction)
    )
    |> group_by_clause(sort_by)
  end

  def get_jobs_by_pagination(
        query,
        opts,
        pagination: %{limit: limit, offset: offset}
      ) do
    query = get_jobs(query, opts)

    from(j in query,
      limit: ^limit,
      offset: ^offset,
      preload: [:client, :package, :job_status, :payment_schedules, :booking_proposals]
    )
  end

  def get_job_by_id(job_id) do
    Repo.get!(Job, job_id)
  end

  def get_client_jobs_query(client_id) do
    from(j in Job,
      where: j.client_id == ^client_id,
      preload: [:package, :shoots, :job_status, :galleries]
    )
  end

  def get_job_shooting_minutes(job) do
    job.shoots
    |> Enum.into([], fn shoot -> shoot.duration_minutes end)
    |> Enum.filter(& &1)
    |> Enum.sum()
  end

  def archive_job(%Job{} = job) do
    now = current_datetime()

    if job.job_status.is_lead do
      job |> Job.archive_changeset() |> Repo.update()
    else
      Ecto.Multi.new()
      |> Ecto.Multi.update(:job, Job.archive_changeset(job))
      |> Ecto.Multi.update_all(:update_payment_schedules, from(ps in PaymentSchedule, where: ps.job_id == ^job.id), set: [reminded_at: now])
      |> Ecto.Multi.update_all(:update_shoots, from(s in Shoot, where: s.job_id == ^job.id), set: [reminded_at: now])
      |> Repo.transaction()
    end
  end

  def unarchive_job(%Job{} = job) do
    job |> Job.unarchive_changeset() |> Repo.update()
  end

  def maybe_upsert_client(%Ecto.Multi{} = multi, %Client{} = new_client, %User{} = current_user) do
    old_client =
      Repo.get_by(Client,
        email: new_client.email |> String.downcase(),
        organization_id: current_user.organization_id
      )

    maybe_upsert_client(multi, old_client, new_client, current_user.organization_id)
  end

  defp maybe_upsert_client(multi, %Client{id: id} = old_client, _new_client, _organization_id)
       when id != nil do
    Ecto.Multi.put(multi, :client, old_client)
  end

  defp maybe_upsert_client(multi, nil = _old_client, new_client, organization_id) do
    Ecto.Multi.insert(
      multi,
      :client,
      new_client
      |> Map.take([:name, :email, :phone])
      |> Map.put(:organization_id, organization_id)
      |> Client.create_changeset()
    )
  end

  def get_job_type(name, organization_id) do
    from(ojt in OrganizationJobType,
      select: %{id: ojt.id, show_on_profile: ojt.show_on_profile?},
      where: ojt.job_type == ^name and ojt.organization_id == ^organization_id
    )
    |> Repo.one()
  end

  def get_all_job_types(organization_id),
    do:
      from(ojt in OrganizationJobType, where: ojt.organization_id == ^organization_id)
      |> Repo.all()

  defp filters_where(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:type, "all"}, dynamic ->
        dynamic

      {:type, value}, dynamic ->
        dynamic(
          [j],
          ^dynamic and j.type == ^value
        )

      {:search_phrase, nil}, dynamic ->
        dynamic

      {:search_phrase, search_phrase}, dynamic ->
        search_phrase = "%#{search_phrase}%"

        dynamic(
          [j, client],
          ^dynamic and
            (ilike(client.name, ^search_phrase) or
               ilike(client.email, ^search_phrase) or
               ilike(client.phone, ^search_phrase) or
               ilike(j.job_name, ^search_phrase))
        )

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  # credo:disable-for-next-line
  defp filters_status(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:status, value}, dynamic ->
        case value do
          "completed" ->
            filter_completed_jobs(dynamic)

          "active" ->
            filter_active(dynamic, "jobs")

          "active_leads" ->
            filter_active(dynamic, "leads")

          "overdue" ->
            filter_overdue_jobs(dynamic)

          "archived" ->
            filter_archived(dynamic)

          "awaiting_contract" ->
            filter_awaiting_contract_leads(dynamic)

          "awaiting_questionnaire" ->
            filter_awaiting_questionnaire_leads(dynamic)

          "pending_invoice" ->
            filter_pending_invoice_leads(dynamic)

          "new" ->
            filter_new_leads(dynamic)

          _ ->
            dynamic
        end

      _any, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filter_completed_jobs(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status == :completed
    )
  end

  defp filter_active(dynamic, "jobs") do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status not in [:completed, :archived]
    )
  end

  defp filter_active(dynamic, "leads") do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status == :sent
    )
  end

  defp filter_new_leads(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status == :not_sent
    )
  end

  defp filter_awaiting_contract_leads(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status == :accepted
    )
  end

  defp filter_awaiting_questionnaire_leads(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status == :signed_with_questionnaire
    )
  end

  defp filter_pending_invoice_leads(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        job_status.current_status in [:signed_without_questionnaire, :answered]
    )
  end

  defp filter_archived(dynamic) do
    dynamic(
      [j, client, job_status],
      ^dynamic and
        not is_nil(j.archived_at)
    )
  end

  defp filter_overdue_jobs(dynamic) do
    dynamic(
      [j, client, job_status, job_status_, shoots, package, payment_schedules],
      ^dynamic and payment_schedules.due_at <= ^current_datetime() and
        is_nil(payment_schedules.paid_at)
    )
  end

  defp current_datetime(), do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  defp group_by_clause(query, :name) do
    group_by(query, [j, client], [j.id, client.name])
  end

  defp group_by_clause(query, :starts_at) do
    group_by(query, [j, client, job_status, job_status_, shoots], [j.id, shoots.starts_at])
  end

  defp group_by_clause(query, _) do
    group_by(query, [j], [j.id])
  end

  defp filter_order_by(:starts_at, order) do
    [
      {order, dynamic([j, client, job_status, job_status_, shoots], field(shoots, :starts_at))}
    ]
  end

  defp filter_order_by(:name, order) do
    [{order, dynamic([j, client], field(client, :name))}]
  end

  defp filter_order_by(column, order) do
    [{order, dynamic([j], field(j, ^column))}]
  end
end
