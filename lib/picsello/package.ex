defmodule Picsello.Package do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Shoot, Accounts.User}
  require Ecto.Query
  import Ecto.Query

  schema "packages" do
    field :archived_at, :utc_datetime
    field :base_multiplier, :decimal, default: 1
    field :base_price, Money.Ecto.Amount.Type
    field :description, :string
    field :download_count, :integer
    field :download_each_price, Money.Ecto.Amount.Type
    field :job_type, :string
    field :name, :string
    field :shoot_count, :integer
    field :print_credits, Money.Ecto.Amount.Type
    field :collected_price, Money.Ecto.Amount.Type
    field :buy_all, Money.Ecto.Amount.Type
    field :turnaround_weeks, :integer, default: 1

    belongs_to(:organization, Picsello.Organization)
    belongs_to(:package_template, __MODULE__, on_replace: :nilify)
    has_many(:jobs, Picsello.Job)

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

  def import_changeset(package \\ %__MODULE__{}, attrs) do
    package
    |> create_details(attrs, skip_description: true)
    |> update_pricing(attrs)
    |> cast(attrs, ~w[collected_price]a)
    |> validate_required(~w[collected_price]a)
    |> then(fn changeset ->
      base_price = get_field(changeset, :base_price) || Money.new(0)

      changeset
      |> validate_money(:collected_price,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: base_price.amount
      )
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
    |> cast(
      attrs,
      ~w[description name organization_id shoot_count print_credits turnaround_weeks]a
    )
    |> validate_required(~w[name organization_id shoot_count turnaround_weeks]a)
    |> validate_number(:shoot_count, less_than_or_equal_to: 10)
    |> validate_number(:turnaround_weeks, greater_than_or_equal_to: 1)
    |> then(fn changeset ->
      if Keyword.get(opts, :skip_description) do
        changeset
      else
        changeset |> validate_required(~w[description]a)
      end
    end)
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
    |> cast(
      attrs,
      ~w[base_price download_count download_each_price base_multiplier print_credits buy_all]a
    )
    |> validate_required(~w[base_price download_count download_each_price]a)
    |> validate_money(:base_price, greater_than_or_equal_to: 200)
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> validate_money(:download_each_price)
    |> then(fn changeset ->
      base_price = get_field(changeset, :base_price) || Money.new(0)

      changeset
      |> validate_money(:print_credits,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: base_price.amount,
        message: "must be equal to or less than total price"
      )
    end)
    |> validate_money(:buy_all)
  end

  def base_price(%__MODULE__{base_price: nil}), do: Money.new(0)
  def base_price(%__MODULE__{base_price: base}), do: base

  def print_credits(%__MODULE__{print_credits: nil}), do: Money.new(0)
  def print_credits(%__MODULE__{print_credits: credits}), do: credits

  def adjusted_base_price(%__MODULE__{base_multiplier: multiplier} = package),
    do: package |> base_price() |> Money.multiply(multiplier)

  def base_adjustment(%__MODULE__{} = package),
    do: package |> adjusted_base_price() |> Money.subtract(base_price(package))

  def price(%__MODULE__{} = package), do: adjusted_base_price(package)

  def templates_for_organization_id(organization_id) do
    from(package in __MODULE__,
      where:
        not is_nil(package.job_type) and package.organization_id == ^organization_id and
          is_nil(package.archived_at),
      order_by: [desc: package.inserted_at]
    )
  end

  def templates_for_user(%User{organization_id: organization_id}),
    do: templates_for_organization_id(organization_id)

  def templates_for_user(user, type) when type != nil do
    from(template in templates_for_user(user), where: template.job_type == ^type)
  end

  def validate_money(changeset, field, validate_number_opts \\ [greater_than_or_equal_to: 0]) do
    validate_change(changeset, field, fn
      field, %Money{amount: amount} ->
        {%{field => nil}, %{field => :integer}}
        |> change(%{field => amount})
        |> validate_number(field, Keyword.put_new(validate_number_opts, :less_than, 999_999))
        |> Map.get(:errors)
        |> Keyword.take([field])
    end)
  end

  defp shoot_count_minimum(package_id) do
    Shoot
    |> join(:inner, [shoot], job in assoc(shoot, :job), on: job.package_id == ^package_id)
    |> Repo.aggregate(:count)
  end
end
