defmodule Picsello.BookingProposal do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Repo, Job, Questionnaire, Questionnaire.Answer}

  schema "booking_proposals" do
    field :accepted_at, :utc_datetime
    field :signed_at, :utc_datetime
    field :signed_legal_name, :string
    field :sent_to_client, :boolean, default: true

    belongs_to(:job, Job)
    belongs_to(:questionnaire, Questionnaire)
    has_one(:answer, Answer, foreign_key: :proposal_id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:sent_to_client, :job_id, :questionnaire_id])
    |> validate_required([:job_id, :sent_to_client])
  end

  @doc false
  def accept_changeset(proposal) do
    attrs = %{accepted_at: DateTime.utc_now()}

    proposal
    |> cast(attrs, [:accepted_at])
    |> validate_required([:accepted_at])
  end

  @doc false
  def sign_changeset(proposal, attrs) do
    attrs = attrs |> Map.put("signed_at", DateTime.utc_now())

    proposal
    |> cast(attrs, [:signed_at, :signed_legal_name])
    |> validate_required([:signed_at, :signed_legal_name])
  end

  @doc "here since used from both emails and views"
  def url(proposal_id, params \\ []), do: build_url(proposal_id, :booking_proposal_url, params)

  def path(proposal_id, params \\ []), do: build_url(proposal_id, :booking_proposal_path, params)

  defp build_url(proposal_id, helper, params) do
    conn = PicselloWeb.Endpoint
    token = Phoenix.Token.sign(conn, "PROPOSAL_ID", proposal_id)
    apply(PicselloWeb.Router.Helpers, helper, [conn, :show, token, params])
  end

  def last_for_job(job_id) do
    job_id |> for_job() |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one()
  end

  def for_job(job_id) do
    __MODULE__ |> where(job_id: ^job_id)
  end

  def by_id(id) do
    Repo.get!(__MODULE__, id)
  end

  def preloads(proposa) do
    proposa
    |> Repo.preload(
      [job: [:client, :shoots, :payment_schedules, package: [organization: :user]]],
      force: true
    )
  end
end
