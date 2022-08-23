defmodule Picsello.Galleries.SessionToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.SessionToken

  @rand_size 64
  @session_validity_in_days 7

  schema "session_tokens" do
    field :token, :string
    field :resource_id, :integer
    field :resource_type, Ecto.Enum, values: [:gallery, :album]

    timestamps(updated_at: false)
  end

  def changeset(attrs \\ %{}) do
    %SessionToken{}
    |> cast(attrs, [:resource_id, :resource_type])
    |> validate_required([:resource_id, :resource_type])
    |> put_token()
    |> foreign_key_constraint(:gallery_id)
  end

  def session_validity_in_days, do: @session_validity_in_days

  defp put_token(changeset) do
    put_change(changeset, :token, :crypto.strong_rand_bytes(@rand_size) |> Base.url_encode64())
  end
end
