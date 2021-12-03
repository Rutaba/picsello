defmodule Picsello.Galleries.SessionToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.SessionToken

  @rand_size 64
  @session_validity_in_days 7

  schema "gallery_session_tokens" do
    field :token, :string
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

  def session_validity_in_days, do: @session_validity_in_days

  defp put_token(changeset) do
    put_change(changeset, :token, :crypto.strong_rand_bytes(@rand_size) |> Base.url_encode64())
  end
end
