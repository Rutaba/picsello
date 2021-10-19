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
    field :base_price, Money.Ecto.Amount.Type
    field :gallery_credit, Money.Ecto.Amount.Type
    field :download_each_price, Money.Ecto.Amount.Type
    field :download_count, :integer
    field :shoot_count, :integer
    belongs_to(:organization, Picsello.Organization)
    belongs_to(:package_template, __MODULE__, on_replace: :nilify)

    timestamps()
  end

  @doc false
  def create_changeset(package \\ %__MODULE__{}, attrs, opts) do
    case Keyword.get(opts, :step, :pricing) do
      :details -> package |> create_details(attrs)
      :pricing -> package |> create_details(attrs) |> update_pricing(attrs)
    end
  end

  defp create_details(package, attrs) do
    package
    |> cast(attrs, [
      :description,
      :name,
      :organization_id,
      :shoot_count
    ])
    |> validate_required([:name, :description, :shoot_count, :organization_id])
    |> validate_number(:shoot_count, less_than_or_equal_to: 10)
  end

  defp update_pricing(package, attrs) do
    package
    |> cast(attrs, [
      :base_price,
      :download_count,
      :download_each_price,
      :gallery_credit
    ])
    |> validate_required([:base_price, :download_count, :download_each_price])
    |> validate_money(:base_price)
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> validate_money(:download_each_price)
    |> validate_money(:gallery_credit)
  end

  def update_changeset(package, %{"package_template_id" => "new"} = attrs) do
    attrs =
      attrs
      |> Map.drop(["package_template_id"])
      |> Map.put(
        "package_template",
        package
        |> create_changeset(attrs, [])
        |> apply_changes()
        |> Map.from_struct()
      )

    package
    |> Repo.preload(:package_template)
    |> update_changeset(attrs)
  end

  def update_changeset(package, attrs, opts \\ []) do
    validate_shoot_count = opts |> Keyword.get(:validate_shoot_count, true)

    changeset =
      package
      |> cast(attrs, [
        :base_price,
        :name,
        :description,
        :shoot_count,
        :package_template_id
      ])
      |> validate_required([:base_price, :name, :description, :shoot_count])
      |> validate_money(:base_price)

    if validate_shoot_count do
      changeset
      |> validate_number(:shoot_count, less_than: 6)
      |> validate_number(:shoot_count, greater_than_or_equal_to: shoot_count_minimum(package))
    else
      changeset
    end
  end

  def downloads_price(%__MODULE__{download_each_price: price, download_count: count})
      when nil in [price, count],
      do: Money.new(0)

  def downloads_price(%__MODULE__{download_each_price: each_price, download_count: count}),
    do: Money.multiply(each_price, count)

  def gallery_credit(%__MODULE__{gallery_credit: nil}), do: Money.new(0)
  def gallery_credit(%__MODULE__{gallery_credit: credit}), do: credit

  def price(%__MODULE__{base_price: nil} = package),
    do: price(%{package | base_price: Money.new(0)})

  def price(%__MODULE__{base_price: base} = package) do
    downloads = downloads_price(package)
    gallery = gallery_credit(package)
    Enum.reduce([base, gallery, downloads], Money.new(0), &Money.add/2)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      _, %Money{amount: amount} when amount >= 0 -> []
      _, _ -> [{field, "must be greater than or equal to 0"}]
    end)
  end

  defp shoot_count_minimum(%{package_template_id: nil}), do: 1

  defp shoot_count_minimum(%{id: package_id}) do
    Shoot
    |> join(:inner, [shoot], job in assoc(shoot, :job), on: job.package_id == ^package_id)
    |> Repo.aggregate(:count)
  end
end
