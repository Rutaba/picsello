defmodule Picsello.Galleries.SessionToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.SessionToken
  alias Picsello.Accounts.User

  @rand_size 64
  @session_validity_in_days 7

  schema "session_tokens" do
    field :token, :string
    field :resource_id, :integer
    field :email, :string
    field :resource_type, Ecto.Enum, values: [:gallery, :album]

    timestamps(updated_at: false)
  end

  def changeset(attrs \\ %{}) do
    %SessionToken{}
    |> cast(attrs, [:resource_id, :resource_type, :email])
    |> validate_required([:resource_id, :resource_type])
    |> User.validate_email_format()
    |> put_token()
  end

  def session_validity_in_days, do: @session_validity_in_days

  defp put_token(changeset) do
    put_change(changeset, :token, :crypto.strong_rand_bytes(@rand_size) |> Base.url_encode64())
  end
end
