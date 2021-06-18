defmodule Picsello.Job do
  @moduledoc false
  @types ~w[wedding family new_born other]

  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Client

  schema "jobs" do
    field :type, :string
    belongs_to(:client, Client)

    timestamps()
  end

  def types(), do: @types

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type])
    |> cast_assoc(:client, with: &Client.create_changeset/2)
    |> validate_required([:type, :client])
    |> validate_inclusion(:type, @types)
  end
end
