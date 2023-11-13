defmodule Picsello.JobType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Picsello.Repo

  @global_type "global"

  @primary_key {:name, :string, []}
  schema "job_types" do
    field(:position, :integer)
  end

  @doc false
  def changeset(job_type \\ %__MODULE__{}, attrs) do
    job_type
    |> cast(attrs, [:name, :position])
    |> validate_required([:name])
  end

  def all() do
    from(t in __MODULE__, select: t.name, order_by: t.position) |> Repo.all()
  end

  def global_type(), do: @global_type
end
