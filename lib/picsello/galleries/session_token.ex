defmodule Picsello.Galleries.SessionToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.SessionToken

  schema "gallery_session_tokens" do
    field :token, :binary
    belongs_to :gallery, Picsello.Galleries.Gallery

    timestamps(updated_at: false)
  end

  def changeset(attrs \\ %{}) do
    %SessionToken{}
    |> cast(attrs, [:gallery_id])
    |> validate_required([:gallery_id])
    |> put_token()
    |> foreign_key_constraint(:gallery_id)
  end

  @rand_size 32
  def put_token(changeset) do
    put_change(changeset, :token, :crypto.strong_rand_bytes(@rand_size))
  end
end
