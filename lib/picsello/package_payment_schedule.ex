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
    field :shoot_date, :date, virtual: true
    field :due_at, :date
    
    belongs_to :package, Package
    belongs_to :package_payment_preset, PackagePaymentPreset

    timestamps()
  end

  def changeset(payment_schedule \\ %__MODULE__{}, attrs \\ %{}, fixed \\ true) do
    interval = payment_schedule |> cast(attrs, [:interval]) |> get_field(:interval)
    is_fixed = fixed && interval && !WizardComponent.is_percentage(attrs["due_interval"])

    attrs = get_percentage(attrs, interval)
    
    payment_schedule
    |> cast(attrs, [:shoot_date, :price, :percentage, :interval, :due_interval, :count_interval, :time_interval, :shoot_interval, :due_at, :package_payment_preset_id, :package_id])
    |> validate_required([:interval])
    |> then(fn changeset -> 
      changeset
      |> validate_price_percentage(is_fixed)
      |> validate_custom_time()
    end)
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

  defp validate_custom_time(changeset), do: if get_field(changeset, :interval), do: changeset, else: validate_shoot_inerval(changeset)
      
  defp validate_shoot_inerval(changeset), do: if get_field(changeset, :shoot_date), do: validate_required(changeset, [:due_at]), else: validate_required(changeset, [:count_interval, :time_interval, :shoot_interval])
    
  defp get_percentage(%{"percentage" => percentage} = attrs, interval) do
    due_interval = attrs |> Map.get("due_interval", nil)
    
    update_percentage = if interval do
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
   
  defp get_percentage(attrs, _), do: attrs

  defp prepare_percentage(nil), do: nil
  defp prepare_percentage("" <> percentage), do: String.trim_trailing(percentage, "%")
  defp prepare_percentage(percentage), do: percentage
end