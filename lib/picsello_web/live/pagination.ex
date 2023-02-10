defmodule PicselloWeb.PaginationLive do
  @moduledoc false

  use Ecto.Schema
  alias Ecto.Changeset

  @types %{
    first_index: :integer,
    last_index: :integer,
    total_count: :integer,
    limit: :integer,
    offset: :integer
  }

  defstruct first_index: 1,
            last_index: 4,
            total_count: 0,
            limit: 4,
            offset: 0

  def changeset(struct \\ %__MODULE__{}, params \\ %{}) do
    {struct, @types}
    |> Changeset.cast(params, Map.keys(@types))
  end
end
