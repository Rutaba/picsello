defmodule Picsello.EmailAutomation.EmailAutomationSetting do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.EmailAutomationPipeline

  @status ~w(active disabled)a

  schema "email_automation_settings" do
    field :name, :string
    field :status, Ecto.Enum, values: @status, default: :active
    field :total_days, :integer
    field :condition, :string

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:organization, Picsello.Organization)

    timestamps type: :utc_datetime
  end

  def changeset(email_setting \\ %__MODULE__{}, attrs) do
    email_setting
    |> cast(
      attrs,
      ~w[status total_days condition name email_automation_pipeline_id organization_id]a
    )
    |> validate_required(~w[status name email_automation_pipeline_id organization_id]a)
  end
end
