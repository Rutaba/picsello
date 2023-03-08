defmodule Picsello.ClientMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Job, ClientMessageRecipient}

  schema "client_messages" do
    belongs_to(:job, Job)
    has_many(:client_message_recipients, ClientMessageRecipient)
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
    |> cast(attrs, [:body_text, :body_html, :job_id, :client_id, :subject])
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
end
