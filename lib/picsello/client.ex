defmodule Picsello.Client do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, Organization, Repo}

  schema "clients" do
    field :email, :string
    field :name, :string
    belongs_to(:organization, Organization)

    timestamps()
  end

  def create_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :organization_id])
    |> User.validate_email_format()
    |> validate_required([:name, :organization_id])
    |> unsafe_validate_unique([:email, :organization_id], Repo)
    |> unique_constraint([:email, :organization_id])
  end
end
