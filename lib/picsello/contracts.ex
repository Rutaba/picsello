defmodule Picsello.Contracts do
  @moduledoc "context module for contracts"
  alias Picsello.{Repo, Job, Contract}
  import Ecto.Query

  def for_job(%Job{} = job) do
    job
    |> for_job_query()
    |> Repo.all()
  end

  def find_by!(%Job{} = job, id) do
    job |> for_job_query() |> where([contract], contract.id == ^id) |> Repo.one!()
  end

  def add_default_contract_to_job(multi, job) do
    default_contract = default_contract(job)

    Ecto.Multi.insert(
      multi,
      :contract,
      default_contract
      |> Map.take([:content, :name])
      |> Map.put(:job_id, job.id)
      |> Map.put(:contract_template_id, default_contract.id)
      |> Contract.changeset()
    )
  end

  def save_contract(organization, job, params) do
    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :contract_template,
        params
        |> Map.put("organization_id", organization.id)
        |> Map.put("job_type", job.type)
        |> Contract.template_changeset()
      )
      |> Ecto.Multi.insert(
        :contract,
        fn changes ->
          params
          |> Map.put("job_id", job.id)
          |> Map.put("contract_template_id", changes.contract_template.id)
          |> Contract.changeset()
        end,
        on_conflict: :replace_all,
        conflict_target: ~w[job_id]a
      )
      |> Repo.transaction()

    case result do
      {:ok, %{contract: contract}} -> {:ok, contract}
      {:error, :contract, changeset, _} -> {:error, changeset}
      _ -> {:error}
    end
  end

  def default_contract(job) do
    job
    |> for_job_query()
    |> where([contract], is_nil(contract.organization_id) and is_nil(contract.job_id))
    |> Repo.one!()
  end

  def contract_content(contract, job, helpers) do
    %{client: %{organization: organization}} = job |> Repo.preload(client: [organization: :user])

    variables = %{
      state: helpers.dyn_gettext(organization.user.onboarding.state),
      organization_name: organization.name,
      turnaround_weeks:
        if(job.package,
          do: helpers.ngettext("1 week", "%{count} weeks", job.package.turnaround_weeks)
        )
    }

    :bbmustache.render(contract.content, variables, key_type: :atom)
  end

  defp for_job_query(%Job{} = job) do
    from(contract in Contract,
      left_join: organization in assoc(contract, :organization),
      left_join: client in assoc(organization, :clients),
      where:
        (client.id == ^job.client_id and contract.organization_id == organization.id and
           ^job.type == contract.job_type) or
          (is_nil(contract.organization_id) and is_nil(contract.job_id)),
      order_by: contract.name
    )
  end
end
