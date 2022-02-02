defmodule Picsello.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema

  @job_states ~w(post_shoot job lead)a

  schema "email_presets" do
    field :body_template, :string
    field :job_state, Ecto.Enum, values: @job_states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string

    timestamps type: :utc_datetime
  end

  def job_states(), do: @job_states
end
