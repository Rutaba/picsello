defmodule Picsello.OrganizationJobType do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Organization, JobType, Repo}

  schema "organization_job_types" do
    field :show_on_profile?, :boolean, default: false
    field :show_on_business?, :boolean, default: false

    belongs_to :jobtype, JobType, references: :name, foreign_key: :job_type, type: :string
    belongs_to(:organization, Organization)

    timestamps()
  end

  @fields ~w[show_on_profile? show_on_business? organization_id job_type]a
  def changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> cast(attrs, @fields)
    |> validate_required([:job_type, :organization_id])
    |> foreign_key_constraint(:job_type)
    |> unique_constraint([:organization_id, :job_type])
  end

  def update_changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> cast(attrs, @fields)
  end

  def get_job_type_by(name, org_id) do
    from(ojt in __MODULE__,
      select: %{id: ojt.id, show_on_profile: ojt.show_on_profile?},
      where: ojt.job_type == ^name and ojt.organization_id == ^org_id
    )
    |> Repo.one()
  end
end
