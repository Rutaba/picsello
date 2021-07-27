defmodule Picsello.BookingProposal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booking_proposals" do
    belongs_to(:job, Picsello.Job)

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:job_id])
    |> validate_required([:job_id])
  end
end
