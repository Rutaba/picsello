defmodule Picsello.ClientTag do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Client

  schema "client_tags" do
    field :name, :string
    belongs_to(:client, Client)

    timestamps()
  end

  def create_changeset(client_tag \\ %__MODULE__{}, attrs) do
    client_tag
    |> cast(attrs, [:name, :client_id])
    |> validate_required([:name, :client_id])
    |> unique_constraint([:name, :client_id])
  end
end
