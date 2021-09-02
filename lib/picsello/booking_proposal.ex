defmodule Picsello.BookingProposal do
  @moduledoc false

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Repo, Job, Questionnaire, Questionnaire.Answer}

  schema "booking_proposals" do
    field :accepted_at, :utc_datetime
    field :signed_at, :utc_datetime
    field :signed_legal_name, :string
    field :deposit_paid_at, :utc_datetime

    belongs_to(:job, Job)
    belongs_to(:questionnaire, Questionnaire)
    has_one(:answer, Answer, foreign_key: :proposal_id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:job_id, :questionnaire_id])
    |> validate_required([:job_id])
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

  @doc false
  def deposit_paid_changeset(proposal) do
    attrs = %{deposit_paid_at: DateTime.utc_now()}

    proposal
    |> cast(attrs, [:deposit_paid_at])
    |> validate_required([:deposit_paid_at])
  end

  @doc "here since used from both emails and views"
  def url(proposal_id), do: build_url(proposal_id, :booking_proposal_url)

  def path(proposal_id), do: build_url(proposal_id, :booking_proposal_path)

  defp build_url(proposal_id, helper) do
    conn = PicselloWeb.Endpoint
    token = Phoenix.Token.sign(conn, "PROPOSAL_ID", proposal_id)
    apply(PicselloWeb.Router.Helpers, helper, [conn, :show, token])
  end

  def last_for_job(job_id) do
    job_id |> for_job() |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one()
  end

  def for_job(job_id) do
    __MODULE__ |> where(job_id: ^job_id)
  end

  def deposit_paid(query \\ __MODULE__) do
    query |> where([p], not is_nil(p.deposit_paid_at))
  end

  def deposit_not_paid(query \\ __MODULE__) do
    query |> where([p], is_nil(p.deposit_paid_at))
  end

  def deposit_paid?(%__MODULE__{deposit_paid_at: nil}), do: false
  def deposit_paid?(%__MODULE__{}), do: true

  def status(%__MODULE__{deposit_paid_at: date}) when date != nil, do: :deposit_paid

  def status(%__MODULE__{answer: %Ecto.Association.NotLoaded{}} = proposal),
    do: proposal |> Repo.preload(:answer) |> status()

  def status(%__MODULE__{answer: answer}) when answer != nil, do: :answered

  def status(%__MODULE__{signed_at: date}) when date != nil, do: :signed
  def status(%__MODULE__{accepted_at: date}) when date != nil, do: :accepted
  def status(%__MODULE__{inserted_at: date}) when date != nil, do: :sent
  def status(nil), do: :not_sent
end
