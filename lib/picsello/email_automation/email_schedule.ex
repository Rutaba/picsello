defmodule Picsello.EmailAutomation.EmailSchedule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline
  }

  alias Picsello.{Job, Galleries.Gallery, Cart.Order, Organization}

  schema "email_schedules" do
    field :total_hours, :integer, default: 0
    field :condition, :string
    # field :template_id, :integer, virtual: true
    field :body_template, :string
    field :name, :string
    field :subject_template, :string
    field :private_name, :string
    field :stopped_at, :utc_datetime, default: nil
    field :reminded_at, :utc_datetime, default: nil

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:job, Job)
    belongs_to(:gallery, Gallery)
    belongs_to(:order, Order)
    belongs_to(:organization, Organization)

    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[email_automation_pipeline_id name private_name subject_template body_template total_hours condition stopped_at reminded_at job_id gallery_id order_id organization_id]a
    )
    |> validate_required(~w[email_automation_pipeline_id subject_template body_template]a)
    |> check_constraint(:job_id, name: :job_gallery_constraint)
  end
end
