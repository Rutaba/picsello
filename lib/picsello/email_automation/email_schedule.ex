defmodule Picsello.EmailAutomation.EmailSchedule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline
  }

  alias Picsello.EmailPresets.EmailPreset

  alias Picsello.{Job, Galleries.Gallery}

  schema "email_schedules" do
    field :total_hours, :integer, default: 0
    field :condition, :string
    field :immediately, :boolean, default: true, virtual: true
    field :count, :integer, virtual: true
    field :calendar, :string, virtual: true
    field :sign, :string, virtual: true
    field :body_template, :string
    field :name, :string
    field :subject_template, :string
    field :private_name, :string
    field :is_stopped, :boolean, default: false
    field :reminded_at, :utc_datetime, default: nil

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:job, Job)
    belongs_to(:gallery, Gallery)

    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[email_automation_pipeline_id name private_name subject_template body_template total_hours condition immediately count calendar sign is_stopped reminded_at job_id gallery_id]a
    )
    |> validate_required(~w[email_automation_pipeline_id subject_template body_template]a)
    |> then(fn changeset ->
      unless get_field(changeset, :immediately) do
        changeset
        |> validate_required([:count])
        |> validate_number(:count, greater_than: 0, less_than_or_equal_to: 31)
        |> put_change(:total_hours, EmailPreset.calculate_hours(changeset))
      else
        changeset
        |> put_change(:count, nil)
        |> put_change(:calendar, nil)
        |> put_change(:sign, nil)
        |> put_change(:total_hours, 0)
      end
    end)
    |> check_constraint(:job_id, name: :job_gallery_constraint)
  end
end
