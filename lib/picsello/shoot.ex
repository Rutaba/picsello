defmodule Picsello.Shoot do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  @locations ~w[studio on_location home]a
  @durations [15, 30, 45, 60, 90, 120, 180, 240, 300, 360]

  def locations(), do: @locations
  def durations(), do: @durations

  schema "shoots" do
    field :duration_minutes, :integer
    field :location, Ecto.Enum, values: @locations
    field :name, :string
    field :notes, :string
    field :starts_at, :utc_datetime
    field :address, :string
    belongs_to(:job, Picsello.Job)

    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:starts_at, :duration_minutes, :name, :location, :notes, :job_id, :address])
    |> validate_required([:starts_at, :duration_minutes, :name, :location, :job_id])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
  end

  def update_changeset(%__MODULE__{} = shoot, attrs) do
    shoot
    |> cast(attrs, [:address, :starts_at, :duration_minutes, :name, :location, :notes])
    |> validate_required([:starts_at, :duration_minutes, :name, :location])
    |> validate_inclusion(:location, @locations)
    |> validate_inclusion(:duration_minutes, @durations)
  end

  def by_starts_at(query \\ __MODULE__) do
    query |> order_by(asc: :starts_at)
  end

  def for_job(job_id) do
    __MODULE__ |> where(job_id: ^job_id) |> by_starts_at()
  end
end
