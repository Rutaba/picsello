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
    lead: ~w(client_contact booking_proposal_sent lead)a,
    job:
      ~w(job post_shoot shoot_thanks offline_payment paid_full balance_due before_shoot booking_event pays_retainer booking_proposal payment_confirmation_client shoot_reminder)a,
    gallery:
      ~w[gallery_send_link cart_abandoned gallery_expiration_soon gallery_password_changed order_confirmation_physical order_confirmation_digital order_confirmation_digital_physical digitals_ready_download order_shipped order_delayed order_arrived gallery_shipping_to_client gallery_shipping_to_photographer album_send_link proofs_send_link]a
  }
  @states @states_by_type |> Map.values() |> List.flatten()

  schema "email_automation_pipelines" do
    field :name, :string
    field :description, :string
    # please emails presets
    field :state, Ecto.Enum, values: @states
    belongs_to(:email_automation_category, EmailAutomationCategory)
    belongs_to(:email_automation_sub_category, EmailAutomationSubCategory)
    has_many(:email_presets, EmailPreset)
    timestamps type: :utc_datetime
  end

  def changeset(email_pipeline \\ %__MODULE__{}, attrs) do
    email_pipeline
    |> cast(
      attrs,
      ~w[status state name description email_automation_category_id email_automation_sub_category_id]a
    )
    |> validate_required(
      ~w[status state name description email_automation_category_id email_automation_sub_category_id]a
    )
  end

  def states(), do: @states
  def states_by_type(), do: @states_by_type
end
