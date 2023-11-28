defmodule Picsello.EmailAutomation.EmailAutomationPipeline do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.{
    EmailAutomationCategory,
    EmailAutomationSubCategory
  }

  alias Picsello.EmailPresets.EmailPreset

  @states_by_type %{
    lead:
      ~w(manual_thank_you_lead client_contact booking_proposal_sent manual_booking_proposal_sent abandoned_emails lead)a,
    job:
      ~w(job post_shoot shoot_thanks offline_payment paid_full paid_offline_full balance_due before_shoot thanks_booking pays_retainer pays_retainer_offline booking_proposal payment_confirmation_client shoot_reminder)a,
    gallery:
      ~w[manual_gallery_send_link gallery_send_link after_gallery_send_feedback cart_abandoned gallery_expiration_soon gallery_password_changed order_confirmation_physical order_confirmation_digital order_confirmation_digital_physical digitals_ready_download order_shipped order_delayed order_arrived gallery_shipping_to_client gallery_shipping_to_photographer album_send_link proofs_send_link manual_send_proofing_gallery manual_send_proofing_gallery_finals]a
  }
  @states @states_by_type |> Map.values() |> List.flatten()

  schema "email_automation_pipelines" do
    field :name, :string
    field :description, :string
    # please emails presets
    field :state, Ecto.Enum, values: @states
    field :position, :float
    belongs_to(:email_automation_category, EmailAutomationCategory)
    belongs_to(:email_automation_sub_category, EmailAutomationSubCategory)
    has_many(:email_presets, EmailPreset)
    timestamps type: :utc_datetime
  end

  def changeset(email_pipeline \\ %__MODULE__{}, attrs) do
    email_pipeline
    |> cast(
      attrs,
      ~w[state name position description email_automation_category_id email_automation_sub_category_id]a
    )
    |> validate_required(
      ~w[state name position description email_automation_category_id email_automation_sub_category_id]a
    )
  end

  def states(), do: @states
  def states_by_type(), do: @states_by_type
end
