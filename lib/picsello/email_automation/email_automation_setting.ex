defmodule Picsello.EmailAutomation.EmailAutomationSetting do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.EmailAutomation.{EmailAutomationPipeline, EmailAutomationType}
  alias Picsello.EmailPresets.EmailPreset

  @status ~w(active disabled)a

  schema "email_automation_settings" do
    field :status, Ecto.Enum, values: @status, default: :active
    field :total_hours, :integer, default: 0
    field :condition, :string
    field :immediately, :boolean, default: true, virtual: true
    field :count, :integer, virtual: true
    field :calendar, :string, virtual: true
    field :sign, :string, virtual: true

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:organization, Picsello.Organization)
    has_one(:email_preset, EmailPreset)
    has_many(:email_automation_types, EmailAutomationType)
    timestamps type: :utc_datetime
  end

  def changeset(email_setting \\ %__MODULE__{}, attrs) do
    email_setting
    |> cast(
      attrs,
      ~w[status total_hours condition email_automation_pipeline_id organization_id immediately count calendar sign]a
    )
    |> validate_required(~w[status email_automation_pipeline_id organization_id]a)
    |> then(fn changeset ->
      unless get_field(changeset, :immediately) do
        changeset
        |> validate_required([:count])
        |> validate_number(:count, greater_than: 0, less_than_or_equal_to: 31)
        |> put_change(:total_hours, calculate_hours(changeset))
      else
        changeset
        |> put_change(:count, nil)
        |> put_change(:calendar, nil)
        |> put_change(:sign, nil)
        |> put_change(:total_hours, 0)
      end
    end)
  end

  def calculate_hours(changeset) do
    data = changeset |> current()
    count = Map.get(data, :count)

    if count do
      calculate_total_hours(count, data)
    else
      0
    end
  end

  defp calculate_total_hours(count, data) do
    hours = case Map.get(data, :calendar) do
      "Hour" -> count
      "Day" -> count * 24
      "Month" -> count * 30  * 24
      "Year" -> count * 365 * 24
    end

    case Map.get(data, :sign) do
      "+" -> hours
      "-" -> String.to_integer("-#{hours}")
    end
  end
end
# 12 date 13
# booking event setting
