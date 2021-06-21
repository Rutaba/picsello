defmodule Picsello.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :description, :string
    field :name, :string
    field :price, :integer
    field :shoot_count, :integer
    belongs_to(:organization, Picsello.Organization)

    timestamps()
  end

  @doc false
  def create_changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> cast(attrs, [:price, :name, :description, :shoot_count, :organization_id])
    |> validate_required([:price, :name, :description, :shoot_count, :organization_id])
    |> validate_number(:price, greater_than_or_equal_to: 0)
  end
end
