defmodule Picsello.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Package, Client, Accounts.User}

  schema "organizations" do
    field(:name, :string)
    field(:stripe_account_id, :string)
    has_many(:package_templates, Package, where: [package_template_id: nil])
    has_many(:clients, Client)
    has_one(:user, User)

    timestamps()
  end

  @doc false
  def registration_changeset(organization \\ %__MODULE__{}, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def assign_stripe_account_changeset(%__MODULE__{} = organization, "" <> stripe_account_id),
    do: organization |> change(stripe_account_id: stripe_account_id)
end
