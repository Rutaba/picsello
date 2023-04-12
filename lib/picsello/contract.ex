defmodule Picsello.Contract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, Package}

  schema "contracts" do
    field :content, :string
    field :name, :string
    field :job_type, :string
    field :edited, :boolean, virtual: true
    field(:status, Ecto.Enum, values: [:active, :archive])
    belongs_to(:organization, Organization)
    belongs_to(:package, Package)
    belongs_to(:contract_template, __MODULE__)

    timestamps()
  end

  def changeset(contract \\ %__MODULE__{}, attrs, opts \\ []) do
    validate_unique_name_on_organization =
      Keyword.get(opts, :validate_unique_name_on_organization)

    skip_package_id = Keyword.get(opts, :skip_package_id)

    contract
    |> cast(attrs, [:name, :content, :package_id, :contract_template_id])
    |> validate_required([:content])
    |> then(fn changeset ->
      if skip_package_id, do: changeset, else: validate_required(changeset, [:package_id])
    end)
    |> then(fn changeset ->
      if validate_unique_name_on_organization do
        changeset
        |> validate_required([:name])
        |> put_change(:organization_id, validate_unique_name_on_organization)
        |> unsafe_validate_unique([:name, :organization_id], Picsello.Repo)
      else
        changeset
      end
    end)
  end

  def template_changeset(contract \\ %__MODULE__{}, attrs) do
    contract
    |> cast(attrs, [:name, :content, :organization_id, :job_type])
    |> validate_required([:name, :content, :organization_id, :job_type])
    |> unsafe_validate_unique([:name, :organization_id], Picsello.Repo)
  end

  def status_changeset(%__MODULE__{} = contract, status) do
    contract |> change(status: status)
  end
end
