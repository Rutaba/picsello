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
      |> Ecto.Multi.insert(:contract, fn changes ->
        params
        |> Map.put("organization_id", organization.id)
        |> Map.put("contract_template_id", changes.contract_template.id)
        |> Contract.changeset()
      end)
      |> Ecto.Multi.update(:job_update, fn changes ->
        Job.add_contract_changeset(job, %{contract_id: changes.contract.id})
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{contract: contract}} -> {:ok, contract}
      {:error, :contract, changeset, _} -> {:error, changeset}
      _ -> {:error}
    end
  end

  defp for_job_query(%Job{} = job) do
    from(contract in Contract,
      join: organization in assoc(contract, :organization),
      join: client in assoc(organization, :clients),
      where:
        client.id == ^job.client_id and contract.organization_id == organization.id and
          ^job.type == contract.job_type,
      order_by: contract.name
    )
  end
end
