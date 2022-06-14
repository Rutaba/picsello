defmodule Picsello.EmailPresets.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(job gallery)a
  @states_by_type %{
    job: ~w(post_shoot booking_proposal job lead)a,
    gallery: ~w[gallery_send_link gallery_shipping_to_client gallery_shipping_to_photographer]a
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

    timestamps type: :utc_datetime
  end

  def changeset(email_preset \\ %__MODULE__{}, attrs) do
    email_preset
    |> cast(attrs, ~w[type state job_type name position subject_template body_template]a)
    |> validate_required(~w[type state name position subject_template body_template]a)
    |> validate_states()
    |> foreign_key_constraint(:job_type)
  end

  defp validate_states(changeset) do
    type = get_field(changeset, :type)
    changeset |> validate_inclusion(:state, Map.get(@states_by_type, type))
  end

  def states(), do: @states
end
