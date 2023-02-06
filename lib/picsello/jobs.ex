defmodule Picsello.Jobs do
  @moduledoc "context module for jobs"
  alias Picsello.{
    Accounts.User,
    Repo,
    Client,
    Job,
    OrganizationJobType
  }

  import Ecto.Query

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

  def archive_lead(%Job{} = job) do
    job |> Job.archive_changeset() |> Repo.update()
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
end
