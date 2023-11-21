defmodule Picsello.EmailPresets.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset
  import PicselloWeb.PackageLive.Shared, only: [current: 1]
  alias Picsello.{EmailAutomation.EmailAutomationPipeline, Organization}

  @types ~w(lead job gallery)a
  @status ~w(active disabled)a
  @states_by_type %{
    lead:
      ~w(manual_thank_you_lead client_contact booking_proposal_sent manual_booking_proposal_sent abandoned_emails lead)a,
    job:
      ~w(job post_shoot shoot_thanks balance_due_offline paid_full paid_offline_full balance_due before_shoot thanks_booking thanks_job pays_retainer pays_retainer_offline booking_proposal payment_confirmation_client shoot_reminder)a,
    gallery:
      ~w[manual_gallery_send_link gallery_send_link after_gallery_send_feedback cart_abandoned gallery_expiration_soon gallery_password_changed order_confirmation_physical order_confirmation_digital order_confirmation_digital_physical digitals_ready_download order_shipped order_delayed order_arrived gallery_shipping_to_client gallery_shipping_to_photographer album_send_link proofs_send_link manual_send_proofing_gallery manual_send_proofing_gallery_finals]a
  }
  @states @states_by_type |> Map.values() |> List.flatten()

  schema "email_presets" do
    field :status, Ecto.Enum, values: @status, default: :active
    field :total_hours, :integer, default: 0
    field :condition, :string
    field :body_template, :string
    field :type, Ecto.Enum, values: @types
    field :state, Ecto.Enum, values: @states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string
    field :position, :integer
    field :private_name, :string
    field :immediately, :boolean, default: true, virtual: true
    field :is_global, :boolean, default: false, virtual: true
    field :count, :integer, virtual: true
    field :calendar, :string, virtual: true
    field :sign, :string, virtual: true
    field :short_codes, :map, virtual: true
    field :template_id, :integer, virtual: true

    belongs_to(:email_automation_pipeline, EmailAutomationPipeline)
    belongs_to(:organization, Organization)

    timestamps type: :utc_datetime
  end

  def default_presets_changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[status email_automation_pipeline_id total_hours state count calendar sign template_id private_name type job_type name position subject_template body_template]a
    )
    |> validate_required(
      ~w[status state status type name position subject_template body_template]a
    )
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(
      attrs,
      ~w[status total_hours state condition email_automation_pipeline_id organization_id is_global immediately count calendar sign template_id private_name type job_type name position subject_template body_template]a
    )
    |> validate_required(
      ~w[status email_automation_pipeline_id type name position subject_template body_template]a
    )
    # |> validate_states()
    |> foreign_key_constraint(:job_type)
    |> then(fn changeset ->
      if get_field(changeset, :immediately) do
        changeset
        |> put_change(:count, nil)
        |> put_change(:calendar, nil)
        |> put_change(:sign, nil)
        |> put_change(:total_hours, 0)
      else
        changeset
        |> validate_required([:count])
        |> validate_count()
        |> put_change(:total_hours, calculate_hours(changeset))
      end
    end)
  end

  defp validate_count(changeset) do
    data = changeset |> current()
    calendar = Map.get(data, :calendar, "Hour")

    case calendar do
      "Hour" -> validate_number(changeset, :count, greater_than: 0, less_than_or_equal_to: 24)
      "Month" -> validate_number(changeset, :count, greater_than: 0, less_than_or_equal_to: 12)
      _ -> validate_number(changeset, :count, greater_than: 0, less_than_or_equal_to: 31)
    end
  end

  # defp validate_states(changeset) do
  #   type = get_field(changeset, :type)
  #   changeset |> validate_inclusion(:state, Map.get(@states_by_type, type))
  # end

  @doc """
  Calculates the total number of hours based on a count value.

  This function takes an Ecto changeset and extracts the `:count` field from it. If a valid count is provided, it
  calculates the total number of hours using the `calculate_total_hours/2` function. If the count is not provided
  or is nil, it returns 0.

  ## Parameters

      - `changeset`: An Ecto changeset containing the `:count` field.

  ## Returns

      The total number of hours calculated from the count value, or 0 if no count is provided.

  ## Example

      ```elixir
      # Calculate hours based on a count value in a changeset
      iex> changeset = Ecto.Changeset.change(%MyApp.Model{}, %{count: 10})
      iex> calculate_hours(changeset)
      10

  ## Notes

  This function is useful for converting a count into a total number of hours.
  """
  def calculate_hours(changeset) do
    data = changeset |> current()
    count = Map.get(data, :count)

    if count, do: calculate_total_hours(count, data), else: 0
  end

  @doc """
  Calculates the total number of hours based on a count and unit data.

  This function takes a count value and unit data as a map. It calculates the total number of hours based on the
  provided count and unit information, considering units like "Hour," "Day," "Month," or "Year," and the sign
  (positive or negative) of the count.

  ## Parameters

      - `count`: The count value to be used in the calculation.
      - `data`: A map containing unit information, such as the unit type and sign.

  ## Returns

      integer(): The total number of hours calculated based on the count and unit data.

  ## Example

      ```elixir
      # Calculate total hours based on a count and unit data
      iex> count = 5
      iex> data = %{calendar: "Month", sign: "+"}
      iex> calculate_total_hours(count, data)
      3600

  ## Notes

  This function is used for converting a count and unit information into a total number of hours.
  """
  def calculate_total_hours(count, data) do
    hours =
      case Map.get(data, :calendar) do
        "Hour" -> count
        "Day" -> count * 24
        "Month" -> count * 30 * 24
        "Year" -> count * 365 * 24
      end

    case Map.get(data, :sign) do
      "+" -> hours
      "-" -> String.to_integer("-#{hours}")
    end
  end

  def states(), do: @states

  @type t :: %__MODULE__{
          id: integer(),
          status: String.t(),
          total_hours: integer(),
          condition: String.t(),
          immediately: boolean(),
          is_global: boolean(),
          count: integer(),
          calendar: String.t(),
          sign: String.t(),
          body_template: String.t(),
          type: String.t(),
          job_type: String.t(),
          name: String.t(),
          subject_template: String.t(),
          position: integer(),
          template_id: integer(),
          private_name: String.t(),
          email_automation_pipeline_id: integer(),
          organization_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
