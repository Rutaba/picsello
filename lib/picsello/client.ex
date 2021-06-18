defmodule Picsello.Client do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Accounts.User

  schema "clients" do
    field :email, :string
    field :name, :string
    belongs_to(:organization, Picsello.Organization)

    timestamps()
  end

  def create_changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :email, :organization_id])
    |> User.validate_email_format()
    |> validate_required([:name, :organization_id])
  end
end
