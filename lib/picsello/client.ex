defmodule Picsello.Client do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, Organization}

  schema "clients" do
    field :email, :string
    field :name, :string
    field :phone, :string
    field :stripe_customer_id, :string
    belongs_to(:organization, Organization)

    timestamps()
  end

  def create_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :organization_id, :phone])
    |> User.validate_email_format()
    |> validate_required([:name, :organization_id, :phone])
    |> validate_change(:phone, &valid_phone/2)
    |> unique_constraint([:email, :organization_id])
  end

  def create_contact_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :organization_id])
    |> User.validate_email_format()
    |> validate_required([:name, :organization_id])
    |> unsafe_validate_unique(:email, Picsello.Repo)
    |> unique_constraint([:email, :organization_id])
  end

  def assign_stripe_customer_changeset(%__MODULE__{} = client, "" <> stripe_customer_id),
    do: client |> change(stripe_customer_id: stripe_customer_id)

  @doc "just make sure there are 10 digits in there somewhere"
  def valid_phone(field, value) do
    if Regex.scan(~r/\d/, value) |> Enum.count() == 10 do
      []
    else
      [{field, "is invalid"}]
    end
  end
end
