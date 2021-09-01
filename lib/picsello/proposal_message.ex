defmodule Picsello.ProposalMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.BookingProposal

  schema "proposal_messages" do
    belongs_to :proposal, BookingProposal
    field(:subject, :string)
    field(:cc_email, :string)
    field(:body_text, :string)
    field(:body_html, :string)

    timestamps()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:subject, :body_text, :body_html, :cc_email])
    |> validate_required([:subject, :body_text, :body_html])
    |> validate_email_format(:cc_email)
  end

  defp validate_email_format(changeset, field) do
    changeset
    |> validate_format(field, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(field, max: 160)
  end
end
