defmodule Picsello.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field :name, :string
    has_many(:package_templates, Picsello.Package, where: [package_template_id: nil])

    timestamps()
  end

  @doc false
  def registration_changeset(organization \\ %__MODULE__{}, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
