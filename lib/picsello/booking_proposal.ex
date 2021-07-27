defmodule Picsello.BookingProposal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booking_proposals" do
    field :accepted_at, :utc_datetime

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
end
