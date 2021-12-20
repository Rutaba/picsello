defmodule Picsello.Packages do
  @moduledoc "context module for packages"
  alias Picsello.{Package, Repo, Job, JobType}

  defmodule Multiplier do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @percent_options for(amount <- 10..100//10, do: {"#{amount}%", amount})
    @sign_options [{"Discount", "-"}, {"Surcharge", "+"}]

    @primary_key false
    embedded_schema do
      field(:percent, :integer, default: @percent_options |> hd |> elem(1))
      field(:sign, :string, default: @sign_options |> hd |> elem(1))
      field(:is_enabled, :boolean)
    end

    def changeset(multiplier \\ %__MODULE__{}, attrs) do
      multiplier
      |> cast(attrs, [:percent, :sign, :is_enabled])
      |> validate_required([:percent, :sign, :is_enabled])
    end

    def percent_options(), do: @percent_options
    def sign_options(), do: @sign_options

    def from_decimal(d) do
      case d |> Decimal.sub(1) |> Decimal.mult(100) |> Decimal.to_integer() do
        0 ->
          %__MODULE__{is_enabled: false}

        percent when percent < 0 ->
          %__MODULE__{percent: abs(percent), sign: "-", is_enabled: true}

        percent when percent > 0 ->
          %__MODULE__{percent: percent, sign: "+", is_enabled: true}
      end
    end

    def to_decimal(%__MODULE__{is_enabled: false}), do: Decimal.new(1)

    def to_decimal(%__MODULE__{sign: sign, percent: percent}) do
      case sign do
        "+" -> percent
        "-" -> Decimal.negate(percent)
      end
      |> Decimal.div(100)
      |> Decimal.add(1)
    end
  end

  defmodule Download do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset
    import Money.Sigils

    @default_each_price ~M[5000]USD
    @zero_price ~M[0]USD

    @primary_key false
    embedded_schema do
      field(:is_enabled, :boolean, default: true)
      field(:is_custom_price, :boolean, default: false)
      field(:includes_credits, :boolean, default: false)
      field(:each_price, Money.Ecto.Amount.Type, default: @default_each_price)
      field(:count, :integer)
    end

    def changeset(download \\ %__MODULE__{}, attrs) do
      download
      |> cast(attrs, [:is_enabled, :is_custom_price, :includes_credits, :each_price, :count])
      |> then(
        &if get_field(&1, :is_enabled),
          do: &1,
          else:
            Enum.reduce(
              [each_price: @zero_price, is_custom_price: false, includes_credits: false],
              &1,
              fn {k, v}, changeset -> force_change(changeset, k, v) end
            )
      )
      |> then(
        &if(get_field(&1, :is_custom_price),
          do:
            &1
            |> force_change(:each_price, get_field(&1, :each_price))
            |> validate_required([:each_price])
            |> Picsello.Package.validate_money(:each_price, greater_than: 0),
          else: force_change(&1, :each_price, @default_each_price)
        )
      )
      |> then(
        &if(get_field(&1, :includes_credits),
          do:
            &1
            |> force_change(:count, get_field(&1, :count))
            |> validate_required([:count])
            |> validate_number(:count, greater_than: 0),
          else: force_change(&1, :count, nil)
        )
      )
    end

    def from_package(%{download_each_price: each_price, download_count: count})
        when each_price in [@default_each_price, nil],
        do: set_count_fields(%__MODULE__{}, count)

    def from_package(%{download_each_price: @zero_price, download_count: count}),
      do:
        set_count_fields(
          %__MODULE__{is_enabled: false, includes_credits: false, each_price: @zero_price},
          count
        )

    def from_package(%{download_each_price: each_price, download_count: count}),
      do: set_count_fields(%__MODULE__{each_price: each_price, is_custom_price: true}, count)

    def count(%__MODULE__{count: nil}), do: 0
    def count(%__MODULE__{count: count}), do: count

    def each_price(%__MODULE__{each_price: each_price}), do: each_price

    def default_each_price(), do: @default_each_price

    defp set_count_fields(download, count) when count in [nil, 0],
      do: %{download | count: nil, includes_credits: false}

    defp set_count_fields(download, count),
      do: %{download | count: count, includes_credits: true}
  end

  def templates_for_user(user, job_type),
    do: user |> Package.templates_for_user(job_type) |> Repo.all()

  def insert_package_and_update_job(changeset, job),
    do:
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:package, changeset)
      |> Ecto.Multi.update(:job, fn changes ->
        Job.add_package_changeset(job, %{package_id: changes.package.id})
      end)
      |> Repo.transaction()

  def build_package_changeset(
        %{
          current_user: current_user,
          step: step,
          is_template: is_template,
          package: package,
          job: job
        },
        params
      ) do
    params = Map.put(params, "organization_id", current_user.organization_id)

    Package.changeset(package, params,
      step: step,
      is_template: is_template,
      validate_shoot_count: job && package.id
    )
  end

  def insert_or_update_package(build_params, client_params),
    do: build_params |> build_package_changeset(client_params) |> Repo.insert_or_update()

  defdelegate job_types(), to: JobType, as: :all

  defdelegate job_name(job), to: Job, as: :name
end