defmodule Picsello.Package do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Shoot}
  require Ecto.Query
  import Ecto.Query

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
    |> validate_number(:shoot_count, less_than: 6)
  end

  def update_changeset(package, attrs) do
    package
    |> cast(attrs, [:price, :name, :description, :shoot_count])
    |> validate_required([:price, :name, :description, :shoot_count])
    |> validate_money(:price)
    |> validate_number(:shoot_count, less_than: 6)
    |> validate_number(:shoot_count, greater_than_or_equal_to: shoot_count_minimum(package))
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      _, %Money{amount: amount} when amount >= 0 -> []
      _, _ -> [{field, "must be greater than or equal to 0"}]
    end)
  end

  defp shoot_count_minimum(%{package_template_id: nil, id: package_id}) do
    Shoot
    |> join(:inner, [shoot], job in assoc(shoot, :job), on: job.package_id == ^package_id)
    |> Repo.aggregate(:count)
  end

  defp shoot_count_minimum(_), do: 1
end
