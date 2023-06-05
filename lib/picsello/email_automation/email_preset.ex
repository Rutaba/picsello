defmodule Picsello.EmailPresets.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.EmailAutomation.EmailAutomationSetting

  @types ~w(lead job gallery)a
  @states_by_type %{
    lead: ~w(client_contact booking_proposal_sent lead)a,
    job:
      ~w(job post_shoot shoot_thanks offline_payment paid_full balance_due before_shoot booking_event pays_retainer booking_proposal payment_confirmation_client shoot_reminder)a,
    gallery:
      ~w[gallery_send_link cart_abandoned gallery_expiration_soon gallery_password_changed order_confirmation_physical order_confirmation_digital order_confirmation_digital_physical digitals_ready_download order_shipped order_delayed order_arrived gallery_shipping_to_client gallery_shipping_to_photographer album_send_link proofs_send_link]a
  }
  @states @states_by_type |> Map.values() |> List.flatten()

  schema "email_presets" do
    field :body_template, :string
    field :type, Ecto.Enum, values: @types
    field :state, Ecto.Enum, values: @states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string
    field :position, :integer
    field :is_default, :boolean, default: true
    field :private_name, :string

    belongs_to(:email_automation_setting, EmailAutomationSetting)

    # has_many() #email_automation_types
    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[email_automation_setting_id is_default private_name type state job_type name position subject_template body_template]a
    )
    |> validate_required(
      ~w[email_automation_setting_id type state name position subject_template body_template]a
    )
    |> validate_states()
    |> foreign_key_constraint(:job_type)
  end

  defp validate_states(changeset) do
    type = get_field(changeset, :type)
    changeset |> validate_inclusion(:state, Map.get(@states_by_type, type))
  end

  def states(), do: @states

  @type t :: %__MODULE__{
          id: integer(),
          body_template: String.t(),
          type: String.t(),
          state: String.t(),
          job_type: String.t(),
          name: String.t(),
          subject_template: String.t(),
          position: integer(),
          is_default: boolean(),
          private_name: String.t(),
          email_automation_setting_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
