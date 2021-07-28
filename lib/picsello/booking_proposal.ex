defmodule Picsello.BookingProposal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booking_proposals" do
    field :accepted_at, :utc_datetime
    field :signed_at, :utc_datetime
    field :signed_legal_name, :string

    belongs_to(:job, Picsello.Job)

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:job_id])
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
end
