defmodule Picsello.Contract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, Job}

  schema "contracts" do
    field :content, :string
    field :name, :string
    field :job_type, :string
    belongs_to(:organization, Organization)
    belongs_to(:job, Job)
    belongs_to(:contract_template, __MODULE__)

    timestamps()
  end

  def changeset(contract \\ %__MODULE__{}, attrs, opts \\ []) do
    validate_unique_name_on_organization =
      Keyword.get(opts, :validate_unique_name_on_organization)

    contract
    |> cast(attrs, [:name, :content, :job_id, :contract_template_id])
    |> validate_required([:content, :job_id])
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
end
