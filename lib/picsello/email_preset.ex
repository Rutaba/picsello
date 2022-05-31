defmodule Picsello.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema

  @types ~w(job)a
  @job_states ~w(post_shoot booking_proposal job lead)a

  schema "email_presets" do
    field :body_template, :string
    field :type, Ecto.Enum, values: @types
    field :job_state, Ecto.Enum, values: @job_states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string
    field :position, :integer

    timestamps type: :utc_datetime
  end

  def job_states(), do: @job_states
end
