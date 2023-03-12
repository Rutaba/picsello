defmodule Picsello.Package do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Repo, Shoot, Accounts.User, PackagePaymentSchedule}
  require Ecto.Query
  import Ecto.Query

  schema "packages" do
    field :archived_at, :utc_datetime
    field :base_multiplier, :decimal, default: 1
    field :base_price, Money.Ecto.Amount.Type
    field :description, :string
    # field :download_status, Ecto.Enum, values: [:limited, :unlimited, :none]
    field :download_count, :integer
    field :download_each_price, Money.Ecto.Amount.Type
    field :job_type, :string
    field :name, :string
    field :shoot_count, :integer
    field :print_credits, Money.Ecto.Amount.Type
    field :collected_price, Money.Ecto.Amount.Type
    field :buy_all, Money.Ecto.Amount.Type
    field :turnaround_weeks, :integer, default: 1
    field :schedule_type, :string
    field :fixed, :boolean, default: true
    field :show_on_public_profile, :boolean, default: false

    belongs_to :questionnaire_template, Picsello.Questionnaire
    belongs_to(:organization, Picsello.Organization)
    belongs_to(:package_template, __MODULE__, on_replace: :nilify)
    has_one(:job, Picsello.Job)
    has_one(:contract, Picsello.Contract)

    has_many(:package_payment_schedules, PackagePaymentSchedule,
      where: [package_payment_preset_id: nil]
    )

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

  @fields ~w[base_price organization_id name download_count download_each_price base_multiplier print_credits buy_all shoot_count turnaround_weeks]a
  def changeset_for_create_gallery(package \\ %__MODULE__{}, attrs) do
    package
    |> cast(attrs, @fields)
    |> put_change(:base_price, Money.new(0))
    |> validate_required(~w[download_count name download_each_price organization_id shoot_count]a)
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> validate_money(:download_each_price)
    |> validate_money(:print_credits,
      greater_than_or_equal_to: 0,
      message: "must be equal to or less than total price"
    )
  end

  def import_changeset(package \\ %__MODULE__{}, attrs) do
    base_price = package |> cast(attrs, [:base_price]) |> get_field(:base_price) || Money.new(0)
    skip_base_price = Money.zero?(base_price)

    package
    |> create_details(attrs, skip_description: true)
    |> update_pricing(attrs, skip_base_price: skip_base_price)
    |> cast(attrs, ~w[collected_price]a)
    |> then(fn changeset ->
      changeset
      |> put_change(:collected_price, get_field(changeset, :collected_price) || Money.new(0))
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

  def edit_visibility_changeset(package),
    do: change(package, %{show_on_public_profile: !package.show_on_public_profile})

  defp choose_template(package, attrs, _opts \\ []) do
    package |> cast(attrs, [:package_template_id])
  end

  defp create_details(package, attrs, opts \\ []) do
    package
    |> cast(
      attrs,
      ~w[schedule_type fixed description questionnaire_template_id name organization_id shoot_count print_credits turnaround_weeks show_on_public_profile]a
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

  defp update_pricing(package, attrs, opts \\ []) do
    package
    |> cast(
      attrs,
      ~w[schedule_type fixed base_price download_count download_each_price base_multiplier print_credits buy_all]a
    )
    |> validate_required(~w[base_price download_count download_each_price]a)
    |> then(fn changeset ->
      if Keyword.get(opts, :skip_base_price) do
        changeset
        |> put_change(:base_price, Money.new(0))
        |> put_change(:print_credits, Money.new(0))
      else
        changeset
        |> validate_required(~w[base_price]a)
        |> put_change(:print_credits, get_field(changeset, :print_credits) || Money.new(0))
        |> validate_money(:base_price, greater_than_or_equal_to: 200)
      end
    end)
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

  def templates_for_organization(organization_id) do
    templates_for_organization_query(organization_id)
    |> where([package], package.show_on_public_profile)
  end

  def templates_for_organization_query(organization_id) do
    from(package in __MODULE__,
      where:
        not is_nil(package.job_type) and package.organization_id == ^organization_id and
          is_nil(package.archived_at),
      order_by: [desc: package.base_price]
    )
  end

  def all_templates_for_organization(organization_id) do
    from(package in __MODULE__,
      where:
        not is_nil(package.job_type) and package.organization_id == ^organization_id and
          is_nil(package.archived_at),
      order_by: [desc: package.base_price]
    )
  end

  def archived_templates_for_organization(organization_id) do
    from(package in __MODULE__,
      where:
        not is_nil(package.job_type) and package.organization_id == ^organization_id and
          not is_nil(package.archived_at),
      order_by: [desc: package.base_price]
    )
  end

  def templates_for_user(%User{organization_id: organization_id}, type) when type != nil do
    from(template in templates_for_organization_query(organization_id),
      where: template.job_type == ^type
    )
  end

  def validate_money(changeset, fields, validate_number_opts \\ [greater_than_or_equal_to: 0])

  def validate_money(changeset, [_ | _] = fields, validate_number_opts) do
    for field <- fields, reduce: changeset do
      changeset ->
        validate_money(changeset, field, validate_number_opts)
    end
  end

  def validate_money(changeset, field, validate_number_opts) do
    validate_change(changeset, field, fn
      field, %Money{amount: amount} ->
        {%{field => nil}, %{field => :integer}}
        |> change(%{field => amount})
        |> validate_number(
          field,
          Keyword.put_new(validate_number_opts, :less_than_or_equal_to, 142_857_000)
        )
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
