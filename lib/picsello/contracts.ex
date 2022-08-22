defmodule Picsello.Contracts do
  @moduledoc "context module for contracts"
  alias Picsello.{Repo, Package, Contract}
  import Ecto.Query

  def for_package(%Package{} = package) do
    package
    |> for_package_query()
    |> Repo.all()
  end

  def find_by!(%Package{} = package, id) do
    package |> for_package_query() |> where([contract], contract.id == ^id) |> Repo.one!()
  end

  def maybe_add_default_contract_to_package_multi(package) do
    contract = package |> Repo.preload(:contract, force: true) |> Map.get(:contract)

    if contract do
      Ecto.Multi.new()
      |> Ecto.Multi.put(:contract, contract)
    else
      default_contract = default_contract(package)

      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :contract,
        default_contract
        |> Map.take([:content, :name])
        |> Map.put(:package_id, package.id)
        |> Map.put(:contract_template_id, default_contract.id)
        |> Contract.changeset()
      )
    end
  end

  def save_template_and_contract(package, params) do
    case insert_template_and_contract_multi(package, params) |> Repo.transaction() do
      {:ok, %{contract: contract}} -> {:ok, contract}
      {:error, :contract, changeset, _} -> {:error, changeset}
      _ -> {:error}
    end
  end

  def insert_template_and_contract_multi(package, params) do
    %{organization_id: organization_id} = package

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :contract_template,
      params
      |> Map.put("organization_id", organization_id)
      |> Map.put("job_type", job_type(package))
      |> Contract.template_changeset()
    )
    |> Ecto.Multi.insert(
      :contract,
      fn changes ->
        params
        |> Map.put("package_id", package.id)
        |> Map.put("contract_template_id", changes.contract_template.id)
        |> Contract.changeset()
      end,
      on_conflict: :replace_all,
      conflict_target: ~w[package_id]a
    )
  end

  def save_contract(package, params) do
    case insert_contract_multi(package, params) |> Repo.transaction() do
      {:ok, %{contract: contract}} -> {:ok, contract}
      {:error, :contract, changeset, _} -> {:error, changeset}
      _ -> {:error}
    end
  end

  def insert_contract_multi(package, params) do
    template_id = Map.get(params, "contract_template_id")

    Ecto.Multi.new()
    |> Ecto.Multi.put(
      :contract_template,
      package
      |> for_package_query()
      |> where([contract], contract.id == ^template_id)
      |> Repo.one!()
    )
    |> Ecto.Multi.insert(
      :contract,
      fn changes ->
        params
        |> Map.put("package_id", package.id)
        |> Map.put("contract_template_id", changes.contract_template.id)
        |> Map.put("name", changes.contract_template.name)
        |> Contract.changeset()
      end,
      on_conflict: :replace_all,
      conflict_target: ~w[package_id]a
    )
  end

  def default_contract(package) do
    package
    |> for_package_query()
    |> where([contract], is_nil(contract.organization_id) and is_nil(contract.package_id))
    |> Repo.one!()
  end

  def contract_content(contract, package, helpers) do
    %{organization: organization} = package |> Repo.preload(organization: :user)

    variables = %{
      state: helpers.dyn_gettext(organization.user.onboarding.state),
      organization_name: organization.name,
      turnaround_weeks: helpers.ngettext("1 week", "%{count} weeks", package.turnaround_weeks)
    }

    :bbmustache.render(contract.content, variables, key_type: :atom)
  end

  defp for_package_query(%Package{} = package) do
    job_type = job_type(package)

    from(contract in Contract,
      where:
        (contract.organization_id == ^package.organization_id and
           ^job_type == contract.job_type) or
          (is_nil(contract.organization_id) and is_nil(contract.package_id)),
      order_by: contract.name
    )
  end

  defp job_type(%Package{job_type: "" <> job_type}), do: job_type

  defp job_type(%Package{} = package),
    do: package |> Repo.preload(:job) |> Map.get(:job) |> Map.get(:type)
end
