defmodule Picsello.Packages do
  @moduledoc "context module for packages"
  alias Picsello.{
    Accounts.User,
    Organization,
    Profiles,
    Package,
    Repo,
    Job,
    JobType,
    Packages.BasePrice,
    Packages.CostOfLivingAdjustment,
    PackagePayments,
    Questionnaire
  }

  import Picsello.Repo.CustomMacros
  import Picsello.Package, only: [validate_money: 3]
  import Ecto.Query, only: [from: 2]

  defmodule PackagePricing do
    @moduledoc "For setting buy_all and print_credits price"
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:is_enabled, :boolean)
    end

    def changeset(package_pricing \\ %__MODULE__{}, attrs) do
      package_pricing
      |> cast(attrs, [:is_enabled])
    end

    def handle_package_params(package, params) do
      case Map.get(params, "package_pricing", %{})
           |> Map.get("is_enabled") do
        "false" -> Map.put(package, "print_credits", Money.new(0))
        _ -> package
      end
    end
  end

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
      field(:buy_all, Money.Ecto.Amount.Type)
      field(:is_buy_all, :boolean)
    end

    def changeset(download \\ %__MODULE__{}, attrs) do
      download
      |> cast(attrs, [
        :is_enabled,
        :is_custom_price,
        :includes_credits,
        :each_price,
        :count,
        :is_buy_all,
        :buy_all
      ])
      |> then(
        &if get_field(&1, :is_enabled),
          do: &1,
          else:
            Enum.reduce(
              [
                each_price: @zero_price,
                is_custom_price: false,
                includes_credits: false,
                is_buy_all: false,
                buy_all: nil
              ],
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
      |> validate_buy_all()
      |> validate_each_price()
    end

    defp validate_buy_all(changeset) do
      download_each_price = get_field(changeset, :each_price) || @zero_price

      changeset
      |> validate_money(:buy_all,
        greater_than: download_each_price.amount,
        message: "Must be greater than digital image price"
      )
    end

    defp validate_each_price(changeset) do
      buy_all = get_field(changeset, :buy_all) || @zero_price

      if Money.zero?(buy_all) do
        changeset
      else
        changeset
        |> validate_money(:each_price,
          less_than: buy_all.amount,
          message: "Must be less than buy all price"
        )
      end
    end

    def from_package(%{download_each_price: each_price, download_count: count} = package)
        when each_price in [@default_each_price, nil],
        do: set_count_fields(%__MODULE__{}, count) |> set_buy_all_fields(package)

    def from_package(%{download_each_price: @zero_price, download_count: count} = package),
      do:
        set_count_fields(
          %__MODULE__{is_enabled: false, includes_credits: false, each_price: @zero_price},
          count
        )
        |> set_buy_all_fields(package)

    def from_package(%{download_each_price: each_price, download_count: count} = package),
      do:
        set_count_fields(%__MODULE__{each_price: each_price, is_custom_price: true}, count)
        |> set_buy_all_fields(package)

    def count(%__MODULE__{count: nil}), do: 0
    def count(%__MODULE__{count: count}), do: count

    def each_price(%__MODULE__{is_enabled: false}), do: @zero_price
    def each_price(%__MODULE__{each_price: each_price}), do: each_price

    def buy_all(%__MODULE__{is_buy_all: false}), do: nil
    def buy_all(%__MODULE__{buy_all: buy_all}), do: buy_all

    def default_each_price(), do: @default_each_price

    defp set_count_fields(download, count) when count in [nil, 0],
      do: %{download | count: nil, includes_credits: false}

    defp set_count_fields(download, count),
      do: %{download | count: count, includes_credits: true}

    defp set_buy_all_fields(download, %{buy_all: %Money{} = buy_all}) do
      %{download | is_buy_all: true, buy_all: buy_all}
    end

    defp set_buy_all_fields(download, _package) do
      %{download | is_buy_all: false, buy_all: nil}
    end
  end

  def templates_with_single_shoot(%User{organization_id: organization_id}) do
    query = Package.templates_for_organization(organization_id)

    from(package in query, where: package.shoot_count == 1)
    |> Repo.all()
  end

  def templates_for_user(user, job_type),
    do: user |> Package.templates_for_user(job_type) |> Repo.all()

  def templates_for_organization(%Organization{id: id}),
    do: id |> Package.templates_for_organization() |> Repo.all()

  def insert_package_and_update_job(changeset, job, opts \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:package, changeset)
    |> maybe_update_questionnaire_package_id_multi(changeset, opts)
    |> Ecto.Multi.update(:job_update, fn changes ->
      Job.add_package_changeset(job, %{package_id: changes.package.id})
    end)
    |> Ecto.Multi.merge(fn %{package: package} ->
      if Map.get(opts, :action) in [:insert, :insert_preset] do
        PackagePayments.insert_schedules(package, opts)
      else
        Ecto.Multi.new()
      end
    end)
    |> Ecto.Multi.merge(fn _ ->
      payment_schedules = Map.get(opts, :payment_schedules)

      shoot_date =
        if payment_schedules && Enum.any?(payment_schedules),
          do: payment_schedules |> List.first() |> Map.get(:shoot_date),
          else: false

      if Map.get(opts, :action) == :insert && shoot_date do
        PackagePayments.insert_job_payment_schedules(Map.put(opts, :job_id, job.id))
      else
        Ecto.Multi.new()
      end
    end)
    |> Ecto.Multi.merge(fn %{package: package} ->
      case package |> Repo.preload(package_template: :contract) do
        %{package_template: %{contract: %Picsello.Contract{} = contract}} ->
          contract_params = %{
            "name" => contract.name,
            "content" => contract.content,
            "contract_template_id" => contract.contract_template_id
          }

          Picsello.Contracts.insert_contract_multi(package, contract_params)

        _ ->
          Ecto.Multi.new()
      end
    end)
  end

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

    package
    |> Map.put(:package_payment_schedules, [])
    |> Package.changeset(params,
      step: step,
      is_template: is_template,
      validate_shoot_count: job && package.id
    )
  end

  def insert_or_update_package(changeset, contract_params, opts) do
    action = Map.get(opts, :action)
    shoot_date = opts.payment_schedules |> List.first() |> Map.get(:shoot_date)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert_or_update(:package, changeset)
      |> Ecto.Multi.merge(fn %{package: %{id: id}} ->
        if action in [:insert, :insert_preset, :update, :update_preset] do
          PackagePayments.delete_schedules(id, Map.get(opts, :payment_preset))
        else
          Ecto.Multi.new()
        end
      end)
      |> Ecto.Multi.merge(fn _ ->
        if action == :update && shoot_date do
          PackagePayments.delete_job_payment_schedules(Map.get(opts, :job_id))
        else
          Ecto.Multi.new()
        end
      end)
      |> Ecto.Multi.merge(fn %{package: package} ->
        if action in [:insert, :insert_preset, :update, :update_preset] do
          PackagePayments.insert_schedules(package, opts)
        else
          Ecto.Multi.new()
        end
      end)
      |> Ecto.Multi.merge(fn _ ->
        if action == :update && shoot_date do
          PackagePayments.insert_job_payment_schedules(opts)
        else
          Ecto.Multi.new()
        end
      end)
      |> Ecto.Multi.merge(fn %{package: package} ->
        contract_multi(package, contract_params)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{package: package}} -> {:ok, package}
      _ -> {:error}
    end
  end

  defp contract_multi(package, contract_params) do
    cond do
      is_nil(contract_params) ->
        Ecto.Multi.new()

      Map.get(contract_params, "edited") ->
        Picsello.Contracts.insert_template_and_contract_multi(package, contract_params)

      !Map.get(contract_params, "edited") ->
        Picsello.Contracts.insert_contract_multi(package, contract_params)
    end
  end

  def changeset_from_template(%Package{id: template_id} = template) do
    template
    |> Map.from_struct()
    |> Map.put(:package_template_id, template_id)
    |> Package.create_from_template_changeset()
  end

  defdelegate job_types(), to: JobType, as: :all

  defdelegate job_name(job), to: Job, as: :name

  defdelegate price(price), to: Package

  def discount_percent(%{base_multiplier: multiplier}),
    do:
      (case(Multiplier.from_decimal(multiplier)) do
         %{sign: "-", is_enabled: true, percent: percent} -> percent
         _ -> nil
       end)

  def create_initial(
        %User{
          onboarding: %{photographer_years: years_experience, schedule: schedule, state: state}
        } = user
      )
      when is_integer(years_experience) and is_atom(schedule) and is_binary(state) do
    %{organization: %{organization_job_types: job_types}} =
      user = Repo.preload(user, organization: :organization_job_types)

    enabled_job_types = Profiles.enabled_job_types(job_types)

    templates_query =
      from q in templates_query(user),
        where: q.job_type in ^enabled_job_types

    {_count, templates} = Repo.insert_all(Package, templates_query, returning: true)

    templates
  end

  def create_initial(_user), do: []

  def create_initial(
        %User{
          onboarding: %{photographer_years: years_experience, schedule: schedule, state: state}
        } = user,
        job_type
      )
      when is_integer(years_experience) and is_atom(schedule) and is_binary(state) do
    templates_query =
      from q in templates_query(user),
        where: q.job_type == ^job_type

    {_count, templates} = Repo.insert_all(Package, templates_query, returning: true)

    templates
  end

  defp minimum_years_query(years_experience),
    do:
      from(base in BasePrice,
        select: max(base.min_years_experience),
        where: base.min_years_experience <= ^years_experience
      )

  defp templates_query(%User{
         onboarding: %{photographer_years: years_experience, schedule: schedule, state: state},
         organization_id: organization_id
       }) do
    full_time = schedule == :full_time
    nearest = 500
    zero_price = Money.new(0)
    default_each_price = Download.default_each_price()

    from(base in BasePrice,
      where:
        base.full_time == ^full_time and
          base.min_years_experience in subquery(minimum_years_query(years_experience)),
      inner_lateral_join:
        name in ([base.tier, base.job_type] |> array_to_string(" ") |> initcap()),
      on: true,
      join: adjustment in CostOfLivingAdjustment,
      on: adjustment.state == ^state,
      select: %{
        base_price:
          type(
            nearest(adjustment.multiplier * base.base_price, ^nearest),
            base.base_price
          ),
        description: coalesce(base.description, name.initcap),
        download_count: base.download_count,
        download_each_price: type(^default_each_price, base.base_price),
        inserted_at: now(),
        job_type: base.job_type,
        buy_all: base.buy_all,
        print_credits: type(^zero_price, base.print_credits),
        name: name.initcap,
        organization_id: type(^organization_id, base.id),
        shoot_count: base.shoot_count,
        turnaround_weeks: base.turnaround_weeks,
        updated_at: now()
      }
    )
  end

  defp maybe_update_questionnaire_package_id_multi(
         multi,
         %{changes: %{organization_id: organization_id}},
         %{questionnaire: questionnaire}
       ) do
    multi
    |> Ecto.Multi.insert(
      :questionnaire,
      fn %{package: %{id: package_id}} ->
        Questionnaire.clean_questionnaire_for_changeset(
          questionnaire,
          organization_id,
          package_id
        )
      end
    )
    |> Ecto.Multi.update(:package_update, fn %{
                                               package: package,
                                               questionnaire: %{id: questionnaire_id}
                                             } ->
      package
      |> Package.changeset(%{questionnaire_template_id: questionnaire_id}, step: nil)
    end)
  end

  defp maybe_update_questionnaire_package_id_multi(multi, _, _), do: multi

  def get_current_user(user_id) do
    from(user in Picsello.Accounts.User,
      where: user.id == ^user_id,
      join: org in assoc(user, :organization),
      left_join: subscription in assoc(user, :subscription),
      preload: [:subscription, [organization: :organization_job_types]]
    )
    |> Repo.one()
  end

  def archive_packages_for_job_type(job_type, organization_id) do
    from(p in Package,
      where: p.organization_id == ^organization_id and p.job_type == ^job_type
    )
    |> Repo.update_all(
      set: [
        archived_at: DateTime.truncate(DateTime.utc_now(), :second),
        show_on_public_profile: false
      ]
    )
  end

  def unarchive_packages_for_job_type(job_type, organization_id) do
    from(p in Package,
      where: p.organization_id == ^organization_id and p.job_type == ^job_type
    )
    |> Repo.update_all(set: [archived_at: nil, show_on_public_profile: false])
  end

  def packages_exist?(job_type, organization_id) do
    from(p in Package,
      where: p.organization_id == ^organization_id and p.job_type == ^job_type
    )
    |> Repo.exists?()
  end

  def unarchive_package(package_id) do
    package = Repo.get(Package, package_id)

    Ecto.Changeset.change(package, archived_at: nil)
    |> Repo.update()
  end

  def paginate_query(query, %{limit: limit, offset: offset}) do
    from query,
      limit: ^limit,
      offset: ^offset
  end
end
