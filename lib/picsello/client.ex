defmodule Picsello.Client do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, Organization, Job, Repo}

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
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_required([:name, :organization_id, :phone])
    |> validate_change(:phone, &valid_phone/2)
    |> unique_constraint([:email, :organization_id])
  end

  def create_contact_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone, :organization_id])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_required([:email, :organization_id])
    |> unsafe_validate_unique(:email, Picsello.Repo)
    |> unique_constraint([:email, :organization_id])
  end

  def edit_contact_changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_required([:email])
    |> unsafe_validate_unique(:email, Picsello.Repo)
    |> unique_constraint([:email])
    |> validate_required_name_and_phone()
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

  def validate_required_name_and_phone(changeset) do
    has_jobs = get_field(changeset, :id) |> Job.by_client_id() |> Repo.exists?()

    if has_jobs do
      changeset |> validate_required([:name, :phone])
    else
      changeset
    end
  end

  defp downcase_email(changeset) do
    email = get_field(changeset, :email)

    if email do
      update_change(changeset, :email, &String.downcase/1)
    else
      changeset
    end
  end
end
