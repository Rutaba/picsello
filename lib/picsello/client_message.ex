defmodule Picsello.ClientMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.Job

  schema "client_messages" do
    belongs_to(:job, Job)
    field(:subject, :string)
    field(:cc_email, :string)
    field(:body_text, :string)
    field(:body_html, :string)
    field(:scheduled, :boolean)
    field(:outbound, :boolean)
    field(:read_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def create_outbound_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:subject, :body_text, :body_html, :cc_email])
    |> validate_required([:subject, :body_text])
    |> validate_email_format(:cc_email)
    |> put_change(:outbound, true)
    |> put_change(:read_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def create_inbound_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:body_text, :body_html, :job_id, :subject])
    |> validate_required([:subject, :body_text, :body_text, :job_id])
    |> put_change(:outbound, false)
  end

  defp validate_email_format(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(field, max: 160)
  end

  def unread_messages(jobs_query) do
    from(message in __MODULE__,
      join: jobs in subquery(jobs_query),
      on: jobs.id == message.job_id,
      where: is_nil(message.read_at)
    )
  end
end
