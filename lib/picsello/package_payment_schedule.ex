defmodule Picsello.PackagePaymentSchedule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{Package, PackagePaymentPreset}

  schema "package_payment_schedules" do
    field :price, Money.Ecto.Amount.Type
    field :percentage, :integer
    field :interval, :boolean, null: false
    field :description, :string, null: false
    field :due_interval, :string
    field :count_interval, :string
    field :time_interval, :string
    field :shoot_interval, :string
    field :due_at, :date
    field :fields_count, :integer, virtual: true
    field :payment_field_index, :integer, virtual: true
    field :shoot_date, :utc_datetime, virtual: true
    field :last_shoot_date, :utc_datetime, virtual: true
    field :schedule_date, :utc_datetime, null: false

    belongs_to :package, Package
    belongs_to :package_payment_preset, PackagePaymentPreset

    timestamps()
  end

  @all_attrs [
    :description,
    :shoot_date,
    :last_shoot_date,
    :price,
    :percentage,
    :interval,
    :due_interval,
    :count_interval,
    :time_interval,
    :shoot_interval,
    :due_at,
    :schedule_date,
    :package_payment_preset_id,
    :package_id,
    :payment_field_index,
    :fields_count
  ]

  def changeset_for_duplication(%__MODULE__{} = payment_schedule, attrs) do
    interval = Map.get(attrs, :interval)

    attrs =
      attrs
      |> prepare_percentage()
      |> set_shoot_interval(interval, false)

    payment_schedule
    |> cast(attrs, @all_attrs)
    |> validate_required([:interval])
    |> then(fn changeset ->
      changeset
      |> validate_price_percentage(true)
      |> validate_custom_time(false)
    end)
  end

  def changeset(
        %__MODULE__{} = payment_schedule,
        attrs \\ %{},
        default_payment_changeset,
        fixed \\ true
      ) do
    interval = payment_schedule |> cast(attrs, [:interval]) |> get_field(:interval)

    attrs =
      attrs
      |> prepare_percentage()
      |> set_shoot_interval(interval, default_payment_changeset)

    payment_schedule
    |> cast(attrs, @all_attrs)
    |> validate_required([:interval])
    |> then(fn changeset ->
      changeset
      |> validate_price_percentage(fixed)
      |> validate_custom_time(default_payment_changeset)
    end)
  end

  def get_default_payment_schedules_values(changeset, field, index) do
    changeset
    |> get_field(:payment_schedules)
    |> Enum.map(&Map.get(&1, field))
    |> Enum.at(index)
  end

  defp validate_price_percentage(changeset, fixed) do
    if fixed do
      changeset
      |> validate_required([:price])
      |> Picsello.Package.validate_money(:price, greater_than: 0)
    else
      changeset
      |> validate_required([:percentage])
      |> validate_number(:percentage, greater_than: 0)
    end
  end

  defp validate_custom_time(changeset, default_payment_changeset),
    do:
      if(get_field(changeset, :interval),
        do: changeset,
        else: validate_shoot_inerval(changeset, default_payment_changeset)
      )

  defp validate_shoot_inerval(changeset, default_payment_changeset) do
    interval =
      if default_payment_changeset,
        do:
          get_default_payment_schedules_values(
            default_payment_changeset,
            :interval,
            get_field(changeset, :payment_field_index)
          ),
        else: false

    if get_field(changeset, :due_at) || (get_field(changeset, :shoot_date) && interval) do
      validate_required(changeset, [:due_at])
    else
      validate_required(changeset, [:count_interval, :time_interval, :shoot_interval])
    end
  end

  def prepare_percentage(%{"percentage" => percentage} = attrs),
    do: %{attrs | "percentage" => prepare_percentage(percentage)}

  def prepare_percentage(nil), do: nil
  def prepare_percentage("" <> percentage), do: String.trim_trailing(percentage, "%")
  def prepare_percentage(percentage), do: percentage

  defp set_shoot_interval(attrs, false, default_payment_changeset) do
    changeset = %__MODULE__{} |> cast(attrs, [:shoot_date, :count_interval, :payment_field_index])

    interval =
      if default_payment_changeset,
        do:
          get_default_payment_schedules_values(
            default_payment_changeset,
            :interval,
            get_field(changeset, :payment_field_index)
          ),
        else: false

    cond do
      get_field(changeset, :due_at) || (interval && get_field(changeset, :shoot_date)) ->
        attrs

      !get_field(changeset, :count_interval) && !get_field(changeset, :shoot_date) ->
        attrs
        |> Map.merge(%{
          "count_interval" => "1",
          "time_interval" => "Day",
          "shoot_interval" => "Before 1st Shoot"
        })

      true ->
        attrs
    end
  end

  defp set_shoot_interval(attrs, _, _), do: attrs
end
