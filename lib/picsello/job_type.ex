defmodule Picsello.JobType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  
  alias Picsello.Repo

  @other_type "other"

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

  def other_type(), do: @other_type
end
