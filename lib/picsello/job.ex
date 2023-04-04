defmodule Picsello.Job do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias Picsello.{
    Client,
    JobStatus,
    Package,
    Shoot,
    BookingProposal,
    Repo,
    ClientMessage,
    PaymentSchedule
  }

  alias Picsello.Galleries.Gallery

  schema "jobs" do
    field(:type, :string)
    field(:notes, :string)
    field(:archived_at, :utc_datetime)
    field(:is_gallery_only, :boolean, default: false)
    field(:completed_at, :utc_datetime)
    field(:job_name, :string)
    belongs_to(:client, Client)
    belongs_to(:package, Package)
    belongs_to(:booking_event, Picsello.BookingEvent)
    has_one(:job_status, JobStatus)
    has_many(:galleries, Gallery)
    has_many(:payment_schedules, PaymentSchedule, preload_order: [asc: :due_at])
    has_many(:shoots, Shoot)
    has_many(:booking_proposals, BookingProposal, preload_order: [desc: :inserted_at])
    has_many(:client_messages, ClientMessage)

    embeds_many :documents, Documents, on_replace: :delete do
      field :name, :string
      field :url, :string
    end

    timestamps(type: :utc_datetime)
  end

  def new_job_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type, :client_id, :notes, :is_gallery_only])
    |> validate_required([:type, :client_id])
    |> foreign_key_constraint(:type)
    |> foreign_key_constraint(:client_id)
  end

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type, :client_id, :notes, :is_gallery_only])
    |> cast_assoc(:client, with: &Client.create_changeset/2)
    |> validate_required([:type])
    |> foreign_key_constraint(:type)
    |> assoc_constraint(:client)
  end

  def create_job_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type, :client_id, :notes, :is_gallery_only])
    |> cast_assoc(:client, with: &Client.create_client_with_name_changeset/2)
    |> validate_required([:type])
    |> foreign_key_constraint(:type)
    |> assoc_constraint(:client)
  end

  def document_changeset(job, attrs) do
    job
    |> change(attrs)
    |> cast_embed(:documents, with: &document/2)
  end

  def document(document, attrs), do: cast(document, attrs, [:url, :name])

  defp timestamp_changeset(job, field) do
    change(job, [{field, DateTime.utc_now() |> DateTime.truncate(:second)}])
  end

  def archive_changeset(job), do: job |> timestamp_changeset(:archived_at)
  def unarchive_changeset(job), do: job |> Ecto.Changeset.change(%{archived_at: nil})
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

  def edit_job_changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, [:job_name])
    |> validate_required([:job_name])
  end

  def name(%__MODULE__{type: type} = job) do
    if job.job_name do
      job.job_name
    else
      %{client: %{name: client_name}} = job |> Repo.preload(:client)
      [client_name, Phoenix.Naming.humanize(type)] |> Enum.join(" ")
    end
  end

  def client(%__MODULE__{} = job), do: job |> Repo.preload(:client) |> Map.get(:client)

  def for_user(%Picsello.Accounts.User{organization_id: organization_id}) do
    from(job in __MODULE__,
      join: client in Client,
      on: client.id == job.client_id,
      where: client.organization_id == ^organization_id
    )
  end

  def by_id(id) do
    from(job in __MODULE__, where: job.id == ^id)
  end

  def by_client_id(id) do
    from(job in __MODULE__, where: job.client_id == ^id)
  end

  def by_type(query \\ __MODULE__, type) do
    from(job in query,
      where: job.type == ^type
    )
  end

  def lead?(%__MODULE__{} = job) do
    %{job_status: %{is_lead: is_lead}} =
      job
      |> Repo.preload(:job_status)

    is_lead
  end

  def imported?(%__MODULE__{job_status: %{current_status: current_status}}),
    do: current_status == :imported

  def leads(query \\ __MODULE__) do
    from(job in query,
      join: status in assoc(job, :job_status),
      where: status.is_lead and job.is_gallery_only == false
    )
  end

  def not_booking(query \\ __MODULE__) do
    from(job in query, where: is_nil(job.booking_event_id))
  end

  def not_leads(query \\ __MODULE__) do
    from(job in query,
      join: status in assoc(job, :job_status),
      where: not status.is_lead or job.is_gallery_only
    )
  end

  def document_path(name, uuid),
    do: "jobs/documents/#{uuid}#{Path.extname(name)}"

  @type t :: %__MODULE__{
          id: integer(),
          type: String.t(),
          notes: String.t(),
          archived_at: DateTime.t(),
          is_gallery_only: boolean(),
          completed_at: DateTime.t(),
          job_name: String.t(),
          client_id: integer(),
          package_id: integer(),
          booking_event_id: integer(),
          job_status: JobStatus.t(),
          galleries: [Gallery.t()],
          payment_schedules: [PaymentSchedule.t()],
          shoots: [Shoot.t()],
          booking_proposals: [BookingProposal.t()],
          client_messages: [ClientMessage.t()],
          documents: [name: String.t(), url: String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
