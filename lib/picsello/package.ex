defmodule Picsello.Package do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :description, :string
    field :name, :string
    field :price, Money.Ecto.Amount.Type
    field :shoot_count, :integer
    belongs_to(:organization, Picsello.Organization)
    belongs_to(:package_template, __MODULE__)

    timestamps()
  end

  @doc false
  def create_changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> cast(attrs, [:price, :name, :description, :shoot_count, :organization_id])
    |> validate_required([:price, :name, :description, :shoot_count, :organization_id])
    |> validate_money(:price)
  end

  def update_changeset(package, attrs) do
    package
    |> cast(attrs, [:price, :name, :description])
    |> validate_required([:price, :name, :description])
    |> validate_money(:price)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      _, %Money{amount: amount} when amount >= 0 -> []
      _, _ -> [{field, "must be greater than or equal to 0"}]
    end)
  end
end
