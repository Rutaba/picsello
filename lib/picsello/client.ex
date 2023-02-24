defmodule Picsello.Client do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Accounts.User, Organization, Job, ClientTag, Repo}

  schema "clients" do
    field :email, :string
    field :name, :string
    field :phone, :string
    field :address, :string
    field :notes, :string
    field :stripe_customer_id, :string
    field :archived_at, :utc_datetime
    belongs_to(:organization, Organization)
    has_many(:jobs, Job)
    has_many(:tags, ClientTag)
    has_many(:client_message_recipients, ClientMessageRecipient)
    has_many(:client_messages, through: [:client_message_recipients, :client_message])

    timestamps(type: :utc_datetime)
  end

  def create_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :organization_id, :phone, :address, :notes])
    |> validate_required([:name, :email, :organization_id])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_change(:phone, &valid_phone/2)
    |> unique_constraint([:email, :organization_id])
  end

  def create_client_with_name_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone, :address, :notes, :organization_id])
    |> validate_required([:email, :name, :organization_id])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_change(:phone, &valid_phone/2)
    |> unsafe_validate_unique([:email, :organization_id], Picsello.Repo)
    |> unique_constraint([:email, :organization_id])
  end

  def create_client_changeset(client \\ %__MODULE__{}, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone, :address, :notes, :organization_id])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_required([:email, :organization_id])
    |> unsafe_validate_unique([:email, :organization_id], Picsello.Repo)
    |> unique_constraint([:email, :organization_id])
  end

  def edit_client_changeset(%__MODULE__{} = client, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone, :address, :notes])
    |> downcase_email()
    |> User.validate_email_format()
    |> validate_required([:email])
    |> unsafe_validate_unique([:email, :organization_id], Picsello.Repo)
    |> unique_constraint([:email, :organization_id])
    |> validate_required_name()
  end

  def assign_stripe_customer_changeset(%__MODULE__{} = client, "" <> stripe_customer_id),
    do: client |> change(stripe_customer_id: stripe_customer_id)

  def archive_changeset(%__MODULE__{} = client) do
    client
    |> change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def notes_changeset(client \\ %__MODULE__{}, attrs) do
    client |> cast(attrs, [:notes])
  end

  @doc "just make sure there are 10 digits in there somewhere"
  def valid_phone(field, value) do
    if Regex.scan(~r/\d/, value) |> Enum.count() == 10 do
      []
    else
      [{field, "is invalid"}]
    end
  end

  def validate_required_name(changeset) do
    has_jobs = get_field(changeset, :id) |> Job.by_client_id() |> Repo.exists?()

    if has_jobs do
      changeset |> validate_required([:name])
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
