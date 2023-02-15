defmodule Picsello.ClientMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.Job

  schema "client_messages" do
    belongs_to(:job, Job)
    has_many(:clients, through: [:client_message_recipients, :client])
    field(:subject, :string)
    field(:body_text, :string)
    field(:body_html, :string)
    field(:scheduled, :boolean)
    field(:outbound, :boolean)
    field(:read_at, :utc_datetime)
    field(:deleted_at, :utc_datetime)

    belongs_to(:job, Job)
    belongs_to(:client, Client)

    timestamps(type: :utc_datetime)
  end

  def create_outbound_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:subject, :body_text, :body_html, :to_email, :cc_email, :bcc_email])
    |> validate_required([:subject, :body_text, :to_email])
    |> validate_email_format(:to_email)
    |> validate_email_format(:cc_email)
    |> validate_email_format(:bcc_email)
    |> put_change(:outbound, true)
    |> put_change(:read_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def create_inbound_changeset(attrs, required_fields \\ []) do
    %__MODULE__{}
    |> cast(attrs, [:body_text, :body_html, :job_id, :subject])
    |> validate_required([:subject, :body_text, :body_text, :job_id])
    |> put_change(:outbound, false)
  end

  defp validate_email_format(changeset, field) do
    changeset
    |> validate_format(field, Picsello.Accounts.User.email_regex(), message: "is invalid")
    |> validate_length(field, max: 160)
  end

  def unread_messages(jobs_query) do
    from(message in __MODULE__,
      join: jobs in subquery(jobs_query),
      on: jobs.id == message.job_id,
      where: is_nil(message.read_at) and is_nil(message.deleted_at)
    )
  end
end
