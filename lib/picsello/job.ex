defmodule Picsello.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Client, Package, Shoot, BookingProposal, Repo}

  schema "jobs" do
    field(:type, :string)
    field(:notes, :string)
    field(:archived_at, :utc_datetime)
    belongs_to(:client, Client)
    belongs_to(:package, Package)
    has_many(:shoots, Shoot)
    has_many(:booking_proposals, BookingProposal)

    timestamps()
  end

  def types, do: from(t in "job_types", select: t.name) |> Repo.all()

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type, :client_id, :notes])
    |> cast_assoc(:client, with: &Client.create_changeset/2)
    |> validate_required([:type])
    |> foreign_key_constraint(:type)
    |> assoc_constraint(:client)
  end

  def update_changeset(job, attrs \\ %{}) do
    job
    |> cast(attrs, [:type, :notes])
    |> cast_assoc(:package, with: &Package.update_changeset/2)
    |> validate_required([:type])
    |> foreign_key_constraint(:type)
    |> assoc_constraint(:package)
  end

  def archive_changeset(job) do
    attrs = %{archived_at: DateTime.utc_now()}

    job
    |> cast(attrs, [:archived_at])
    |> validate_required([:archived_at])
  end

  def add_package_changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, [:package_id])
    |> validate_required([:package_id])
    |> assoc_constraint(:package)
  end

  def name(%__MODULE__{type: type} = job) do
    %{client: %{name: client_name}} = job |> Repo.preload(:client)
    [client_name, Phoenix.Naming.humanize(type)] |> Enum.join(" ")
  end

  def for_user(%Picsello.Accounts.User{organization_id: organization_id}) do
    from(job in __MODULE__,
      join: client in Client,
      on: client.id == job.client_id,
      where: client.organization_id == ^organization_id
    )
  end

  def lead?(%__MODULE__{} = job) do
    job
    |> Repo.preload(:booking_proposals)
    |> Map.get(:booking_proposals)
    |> Enum.all?(&(not BookingProposal.deposit_paid?(&1)))
  end

  def leads(query \\ __MODULE__) do
    query
    |> from(as: :jobs)
    |> where(not exists(paid_proposal_sub()))
  end

  def not_leads(query \\ __MODULE__) do
    query
    |> from(as: :jobs)
    |> where(exists(paid_proposal_sub()))
  end

  defp paid_proposal_sub(),
    do: BookingProposal.deposit_paid() |> where([p], p.job_id == parent_as(:jobs).id)
end
