defmodule Picsello.EmailAutomation.EmailAutomationSetting do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset
  import PicselloWeb.PackageLive.Shared, only: [current: 1]

  alias Picsello.EmailAutomation.EmailAutomationPipeline

  @status ~w(active disabled)a

  schema "email_automation_settings" do
    field :name, :string
    field :status, Ecto.Enum, values: @status, default: :active
    field :total_days, :integer, default: 0
    field :condition, :string
    field :immediately, :boolean, default: true, virtual: true
    field :count, :integer, virtual: true
    field :calendar, :string, virtual: true
    field :sign, :string, virtual: true

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:organization, Picsello.Organization)
    # has_one() #email_preset
    # has_many() #email_automation_types
    timestamps type: :utc_datetime
  end

  def changeset(email_setting \\ %__MODULE__{}, attrs) do
    email_setting
    |> cast(
      attrs,
      ~w[status total_days condition name email_automation_pipeline_id organization_id immediately count calendar sign]a
    )
    |> validate_required(~w[status email_automation_pipeline_id organization_id]a)
    # |> then(&if(Map.get(attrs, "step") == :edit_email, do: &1 |> validate_required([:name]) else: &1))
    |> then(&force_change(&1, :total_days, calculate_days(&1)))
    |> then(fn changeset ->
      unless get_field(changeset, :immediately) do
        changeset
        |> validate_required([:count])
        |> validate_number(:count, greater_than: 0, less_than_or_equal_to: 31)
      else
        changeset
      end
    end)
  end

  defp calculate_days(changeset) do
    data = changeset |> current()
    count = Map.get(data, :count)

    if count do
      calculate_total_days(count, data)
    else
      0
    end
  end

  defp calculate_total_days(count, data) do
    days = case Map.get(data, :calendar) do
      "Day" -> count
      "Month" -> count * 30
      "Year" -> count * 365
    end

    case Map.get(data, :sign) do
      "+" -> days
      "-" -> String.to_integer("-#{days}")
    end
  end
end
