defmodule Picsello.PackagePaymentSchedule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{Package, PackagePaymentPreset}
  alias PicselloWeb.PackageLive.WizardComponent

  schema "package_payment_schedules" do
    field :price, Money.Ecto.Amount.Type
    field :percentage, :integer
    field :interval, :boolean
    field :due_interval, :string
    field :count_interval, :string
    field :time_interval, :string
    field :shoot_interval, :string
    field :payment_field_index, :integer, virtual: true
    field :shoot_date, :date, virtual: true
    field :last_shoot_date, :date, virtual: true
    field :due_at, :date
    field :schedule_date, :date

    belongs_to :package, Package
    belongs_to :package_payment_preset, PackagePaymentPreset

    timestamps()
  end

  def changeset(
        %__MODULE__{} = payment_schedule,
        attrs \\ %{},
        default_payment_changeset,
        fixed \\ true
      ) do
    interval = payment_schedule |> cast(attrs, [:interval]) |> get_field(:interval)

    is_fixed =
      (fixed && interval && !WizardComponent.is_percentage(attrs["due_interval"])) ||
        (fixed && !interval)

    attrs =
      set_percentage(attrs, interval) |> set_shoot_interval(interval, default_payment_changeset)

    payment_schedule
    |> cast(attrs, [
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
      :payment_field_index
    ])
    |> validate_required([:interval])
    |> then(fn changeset ->
      changeset
      |> validate_price_percentage(is_fixed)
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

    if get_field(changeset, :shoot_date) && interval do
      validate_required(changeset, [:due_at])
    else
      validate_required(changeset, [:count_interval, :time_interval, :shoot_interval])
    end
  end

  defp set_percentage(%{"percentage" => percentage} = attrs, interval) do
    due_interval = attrs |> Map.get("due_interval", nil)

    update_percentage =
      if interval do
        cond do
          String.contains?(due_interval, "100%") -> 100
          String.contains?(due_interval, "50%") -> 50
          String.contains?(due_interval, "34%") -> 34
          String.contains?(due_interval, "33%") -> 33
          true -> prepare_percentage(percentage)
        end
      else
        prepare_percentage(percentage)
      end

    %{attrs | "percentage" => update_percentage}
  end

  defp set_percentage(attrs, _), do: attrs

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
      interval && get_field(changeset, :shoot_date) ->
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

  defp prepare_percentage(nil), do: nil
  defp prepare_percentage("" <> percentage), do: String.trim_trailing(percentage, "%")
  defp prepare_percentage(percentage), do: percentage
end
