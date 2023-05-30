defmodule Picsello.EmailAutomation.EmailAutomationType do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.EmailAutomationSetting
  alias Picsello.EmailPresets.EmailPreset

  schema "email_automation_types" do
    belongs_to(:email_automation_setting, EmailAutomationSetting)
    belongs_to(:email_preset, EmailPreset)
    belongs_to(:organization_job_type, Picsello.OrganizationJobType, foreign_key: :organization_job_id)
    timestamps type: :utc_datetime
  end

  def changeset(email_type \\ %__MODULE__{}, attrs) do
    email_type
    |> cast(
      attrs,
      ~w[email_automation_setting_id email_preset_id organization_job_id]a
    )
    |> validate_required(~w[email_automation_setting_id email_preset_id organization_job_id]a)
  end
end
