defmodule Picsello.Contracts do
  @moduledoc "context module for contracts"
  import Ecto.Query

  alias Picsello.{Repo, Package, Contract}
  alias Ecto.{Query, Multi}

  def for_package(%Package{} = package) do
    package
    |> for_package_query()
    |> Repo.all()
  end

  def find_by!(%Package{} = package, id) do
    package |> for_package_query() |> where([contract], contract.id == ^id) |> Repo.one!()
  end

  def maybe_add_default_contract_to_package_multi(package) do
    contract = package |> Ecto.assoc(:contract) |> Repo.one()

    if contract do
      Multi.new()
    else
      default_contract = default_contract(package)

      Multi.new()
      |> Multi.insert(
        :default_contract,
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

    Multi.new()
    |> Multi.insert(
      :contract_template,
      params
      |> Map.put("organization_id", organization_id)
      |> Map.put("job_type", job_type(package))
      |> Contract.template_changeset()
    )
    |> Multi.insert(
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

  def insert_contract_multi(package, %{"contract_template_id" => template_id} = params) do
    Multi.new()
    |> Multi.put(
      :contract_template,
      package
      |> for_package_query()
      |> where([contract], contract.id == ^template_id)
      |> Repo.one!()
    )
    |> Multi.insert(
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

  def insert_contract_multi(package, params),
    do: insert_template_and_contract_multi(package, params)

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

  def default_contract_content(contract, organization, helpers) do
    variables = %{
      state: helpers.dyn_gettext(organization.onboarding.state),
      organization_name: organization.name,
      turnaround_weeks: helpers.ngettext("1 week", "%{count} weeks", 1)
    }

    :bbmustache.render(contract.content, variables, key_type: :atom)
  end

  defp for_package_query(%Package{} = package) do
    job_type = job_type(package)

    from(contract in Contract,
      where:
        (contract.organization_id == ^package.organization_id and
           (^job_type == contract.job_type or contract.job_type == "global")) or
          (is_nil(contract.organization_id) and is_nil(contract.package_id)),
      order_by: contract.name
    )
  end

  def get_default_template() do
    from(contract in Contract,
      where: is_nil(contract.organization_id) and is_nil(contract.package_id),
      order_by: contract.name
    )
    |> Repo.one!()
  end

  def for_organization(organization_id, %{pagination: %{limit: limit, offset: offset}} = opts) do
    get_organization_contracts(organization_id, opts)
    |> Query.limit(^limit)
    |> Query.offset(^offset)
    |> Repo.all()
  end

  def get_contract_by_id(contract_id),
    do: get_contract(contract_id) |> Repo.one()

  def update_contract_status(contract_id, status) do
    get_contract_by_id(contract_id)
    |> Contract.status_changeset(status)
    |> Repo.update()
  end

  def clean_contract_for_changeset(
        contract,
        organization_id,
        package_id \\ nil
      ) do
    %Picsello.Contract{
      organization_id: organization_id,
      content: contract.content,
      package_id: package_id,
      name: contract.name,
      job_type: contract.job_type
    }
  end

  def delete_contract_by_id(contract_id),
    do:
      get_contract_by_id(contract_id)
      |> Repo.delete()

  defp get_contract(contract_id),
    do: from(c in Contract, where: c.id == ^contract_id)

  def get_organization_contracts(organization_id, opts) do
    Contract
    |> where([c], c.organization_id == ^organization_id)
    |> or_where([c], is_nil(c.organization_id) and is_nil(c.package_id))
    |> where(^filters_where(opts))
    |> where(^filters_status(opts))
    |> order_by([c], asc: c.job_type, asc: c.name)
  end

  defp filters_where(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:type, "all"}, dynamic ->
        dynamic

      {:type, value}, dynamic ->
        dynamic([c], ^dynamic and c.job_type == ^value)

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filters_status(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {:status, value}, dynamic ->
        case value do
          "current" ->
            filter_current_contracts(dynamic)

          "archived" ->
            filter_archived_contracts(dynamic)

          _ ->
            dynamic
        end

      _any, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp filter_current_contracts(dynamic) do
    dynamic(
      [c],
      ^dynamic and c.status == :active
    )
  end

  defp filter_archived_contracts(dynamic) do
    dynamic(
      [c],
      ^dynamic and c.status == :archive
    )
  end

  defp job_type(%Package{job_type: "" <> job_type}), do: job_type

  defp job_type(%Package{} = package),
    do: package |> Repo.preload(:job) |> Map.get(:job) |> Map.get(:type)
end
