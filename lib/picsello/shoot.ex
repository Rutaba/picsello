defmodule Picsello.Shoot do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @locations ~w[studio on_location home]
  @durations [15, 30, 45, 60, 90, 120]

  def locations(), do: @locations
  def durations(), do: @durations

  schema "shoots" do
    field :duration_minutes, :integer
    field :location, :string
    field :name, :string
    field :notes, :string
    field :starts_at, :utc_datetime
    belongs_to(:job, Picsello.Job)

    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:starts_at, :duration_minutes, :name, :location, :notes, :job_id])
    |> validate_required([:starts_at, :duration_minutes, :name, :location, :job_id])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
  end

  def update_changeset(shoot, attrs) do
    shoot
    |> cast(attrs, [:starts_at, :duration_minutes, :name, :location, :notes])
    |> validate_required([:starts_at, :duration_minutes, :name, :location])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
  end
end
