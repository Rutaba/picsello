defmodule Picsello.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Client, JobStatus, Package, Shoot, BookingProposal, Repo}

  schema "jobs" do
    field(:type, :string)
    field(:notes, :string)
    field(:archived_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    belongs_to(:client, Client)
    belongs_to(:package, Package)
    has_one(:job_status, JobStatus)
    has_many(:shoots, Shoot)
    has_many(:booking_proposals, BookingProposal, preload_order: [desc: :inserted_at])

    timestamps(type: :utc_datetime)
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

  defp timestamp_changeset(job, field) do
    change(job, [{field, DateTime.utc_now() |> DateTime.truncate(:second)}])
  end

  def archive_changeset(job), do: job |> timestamp_changeset(:archived_at)
  def complete_changeset(job), do: job |> timestamp_changeset(:completed_at)

  def add_package_changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, [:package_id])
    |> validate_required([:package_id])
    |> assoc_constraint(:package)
  end

  def notes_changeset(job \\ %__MODULE__{}, attrs) do
    job |> cast(attrs, [:notes])
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
    %{job_status: %{is_lead: is_lead}} =
      job
      |> Repo.preload(:job_status)

    is_lead
  end

  def leads(query \\ __MODULE__) do
    from(job in query, join: status in assoc(job, :job_status), where: status.is_lead)
  end

  def not_leads(query \\ __MODULE__) do
    from(job in query, join: status in assoc(job, :job_status), where: not status.is_lead)
  end
end
