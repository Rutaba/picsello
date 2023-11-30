defmodule Picsello.EmailAutomation.EmailScheduleHistory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline
  }

  @types ~w(lead job shoot gallery order)a
  @stopped_reason_values ~w(photographer_stopped proposal_accepted already_paid_full shoot_starts_at_passed gallery_already_shared_because_order_placed archived completed lead_converted_to_job globally_stopped)a
  alias Picsello.{Job, Shoot, Galleries.Gallery, Cart.Order, Organization}

  schema "email_schedules_history" do
    field :total_hours, :integer, default: 0
    field :type, Ecto.Enum, values: @types
    field :condition, :string
    field :body_template, :string
    field :name, :string
    field :subject_template, :string
    field :private_name, :string
    field :stopped_at, :utc_datetime, default: nil
    field :reminded_at, :utc_datetime, default: nil
    field :stopped_reason, Ecto.Enum, values: @stopped_reason_values
    field :approval_required, :boolean, default: false

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:job, Job)
    belongs_to(:shoot, Shoot)
    belongs_to(:gallery, Gallery)
    belongs_to(:order, Order)
    belongs_to(:organization, Organization)

    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[email_automation_pipeline_id name type private_name subject_template body_template total_hours condition stopped_at stopped_reason reminded_at job_id shoot_id gallery_id order_id organization_id approval_required]a
    )
    |> validate_required(~w[email_automation_pipeline_id type subject_template body_template]a)
  end
end
