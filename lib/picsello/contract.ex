defmodule Picsello.Contract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, JobType}

  schema "contracts" do
    field :content, :string
    field :name, :string
    field :job_types, {:array, :string}
    belongs_to(:organization, Organization)
    belongs_to(:contract_template, __MODULE__)

    timestamps()
  end

  def changeset(contract \\ %__MODULE__{}, attrs, opts \\ []) do
    validate_unique_name = Keyword.get(opts, :validate_unique_name)

    contract
    |> cast(attrs, [:name, :content, :organization_id, :contract_template_id])
    |> validate_required([:name, :content, :organization_id])
    |> then(fn changeset ->
      if validate_unique_name do
        changeset |> unsafe_validate_unique([:name, :organization_id], Picsello.Repo)
      else
        changeset
      end
    end)
  end

  def template_changeset(contract \\ %__MODULE__{}, attrs) do
    contract
    |> cast(attrs, [:name, :content, :organization_id, :job_types])
    |> validate_required([:name, :content, :organization_id, :job_types])
    |> validate_subset(:job_types, JobType.all())
    |> unsafe_validate_unique([:name, :organization_id], Picsello.Repo)
  end
end
