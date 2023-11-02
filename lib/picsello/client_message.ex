defmodule Picsello.ClientMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Repo, Job, ClientMessageRecipient, ClientMessageAttachment}

  schema "client_messages" do
    belongs_to(:job, Job)
    has_many(:client_message_recipients, ClientMessageRecipient)
    has_many(:client_message_attachments, ClientMessageAttachment)
    has_many(:clients, through: [:client_message_recipients, :client])
    field(:subject, :string)
    field(:body_text, :string)
    field(:body_html, :string)
    field(:scheduled, :boolean)
    field(:outbound, :boolean)
    field(:read_at, :utc_datetime)
    field(:deleted_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def create_outbound_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:subject, :body_text, :body_html])
    |> validate_required([
      :subject,
      if(Map.has_key?(attrs, :body_text), do: :body_text, else: :body_html)
    ])
    |> put_change(:outbound, true)
    |> put_change(:read_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> cast_assoc(:client_message_recipients, with: &ClientMessageRecipient.changeset/2)
  end

  def create_inbound_changeset(attrs, required_fields \\ []) do
    %__MODULE__{}
    |> cast(attrs, [:body_text, :body_html, :job_id, :subject])
    |> then(fn changeset ->
      if Enum.any?(required_fields) do
        changeset
        |> validate_required(required_fields)
      else
        changeset
      end
    end)
    |> put_change(:outbound, false)
  end

  def unread_messages(jobs_query) do
    from(message in __MODULE__,
      join: jobs in subquery(jobs_query),
      on: jobs.id == message.job_id,
      where: is_nil(message.read_at) and is_nil(message.deleted_at)
    )
  end

  @doc """
  Retrieves client messages associated with a job and matching subjects.

  This function queries the database to retrieve client messages that are associated with a specific job, have subjects
  that match the provided list of subjects, and are inbound (outbound is false). It filters messages based on the client
  message recipients, ensuring that the recipients are of type :to and belong to the specified job's client.

  ## Parameters

      - `job`: The job entity for which client messages are to be retrieved.
      - `subjects`: A list of subjects to match when retrieving messages.

  ## Returns

      A list of client messages associated with the job and matching subjects.

  ## Example

      ```elixir
      # Retrieve client messages for a job with specified subjects
      iex> job = MyApp.Job.get_job(123)
      iex> subjects = ["Request Information", "Confirmation"]
      iex> get_client_messages(job, subjects)
      [%MyApp.ClientMessage{}, %MyApp.ClientMessage{}]

  ## Notes

  This function is used to fetch relevant client messages associated with a specific job and subjects.
  """
  def get_client_messages(job, subjects) do
    from(
      mesage in __MODULE__,
      join: recipient in assoc(mesage, :client_message_recipients),
      on: mesage.id == recipient.client_message_id,
      where:
        mesage.subject in ^subjects and mesage.job_id == ^job.id and mesage.outbound == false,
      where: recipient.client_id == ^job.client.id and recipient.recipient_type == :to
    )
    |> Repo.all()
  end

  @type t :: %__MODULE__{
          id: integer(),
          subject: String.t(),
          body_text: String.t(),
          body_html: String.t(),
          scheduled: boolean(),
          outbound: boolean(),
          read_at: DateTime.t(),
          deleted_at: DateTime.t(),
          job_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
