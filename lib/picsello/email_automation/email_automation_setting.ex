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
    
    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(attrs, ~w[status total_days condition name email_automation_pipeline_id]a)
    |> validate_required(~w[status name email_automation_pipeline_id]a)
  end
end
