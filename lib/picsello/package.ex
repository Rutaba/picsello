defmodule Picsello.Package do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Shoot, Accounts.User}
  require Ecto.Query
  import Ecto.Query

  schema "packages" do
    field :archived_at, :utc_datetime
    field :base_price, Money.Ecto.Amount.Type
    field :description, :string
    field :download_count, :integer
    field :download_each_price, Money.Ecto.Amount.Type
    field :gallery_credit, Money.Ecto.Amount.Type
    field :job_type, :string
    field :name, :string
    field :shoot_count, :integer

    belongs_to(:organization, Picsello.Organization)
    belongs_to(:package_template, __MODULE__, on_replace: :nilify)

    timestamps()
  end

  def changeset(package \\ %__MODULE__{}, attrs, opts) do
    steps = [
      choose_template: &choose_template/3,
      details: &create_details/3,
      pricing: &update_pricing/3
    ]

    step = Keyword.get(opts, :step, :pricing)

    Enum.reduce_while(steps, package, fn {step_name, initializer}, changeset ->
      {if(step_name == step, do: :halt, else: :cont), initializer.(changeset, attrs, opts)}
    end)
  end

  def create_from_template_changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> choose_template(attrs)
    |> validate_required([:package_template_id])
    |> create_details(attrs)
    |> update_pricing(attrs)
  end

  def archive_changeset(package),
    do: change(package, %{archived_at: DateTime.truncate(DateTime.utc_now(), :second)})

  defp choose_template(package, attrs, _opts \\ []) do
    package |> cast(attrs, [:package_template_id])
  end

  defp create_details(package, attrs, opts \\ []) do
    package
    |> cast(attrs, [
      :description,
      :name,
      :organization_id,
      :shoot_count
    ])
    |> validate_required([:name, :description, :shoot_count, :organization_id])
    |> validate_number(:shoot_count, less_than_or_equal_to: 10)
    |> then(fn changeset ->
      if Keyword.get(opts, :is_template) do
        changeset |> cast(attrs, [:job_type]) |> validate_required([:job_type])
      else
        changeset
      end
    end)
    |> then(fn changeset ->
      if Keyword.get(opts, :validate_shoot_count) do
        package_id = Ecto.Changeset.get_field(changeset, :id)

        changeset
        |> validate_number(:shoot_count, greater_than_or_equal_to: shoot_count_minimum(package_id))
      else
        changeset
      end
    end)
  end

  defp update_pricing(package, attrs, _opts \\ []) do
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

  def templates_for_user(%User{organization_id: organization_id}) do
    from(package in __MODULE__,
      where:
        not is_nil(package.job_type) and package.organization_id == ^organization_id and
          is_nil(package.archived_at),
      order_by: [desc: package.inserted_at]
    )
  end

  def templates_for_user(user, type) when type != nil do
    from(template in templates_for_user(user), where: template.job_type == ^type)
  end

  defp validate_money(changeset, field) do
    validate_change(changeset, field, fn
      _, %Money{amount: amount} when amount >= 0 -> []
      _, _ -> [{field, "must be greater than or equal to 0"}]
    end)
  end

  defp shoot_count_minimum(package_id) do
    Shoot
    |> join(:inner, [shoot], job in assoc(shoot, :job), on: job.package_id == ^package_id)
    |> Repo.aggregate(:count)
  end
end
