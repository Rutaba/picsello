defmodule Picsello.JobType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Query
  alias Picsello.Repo

  @primary_key {:name, :string, []}
  schema "job_types" do
    field(:position, :integer)
  end

  def all() do
    from(t in __MODULE__, select: t.name, order_by: t.position) |> Repo.all()
  end
end
