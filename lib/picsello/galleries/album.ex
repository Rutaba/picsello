defmodule Picsello.Galleries.Album do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  alias Picsello.Galleries.{Gallery, SessionToken, Photo}

  @session_opts [
    foreign_key: :resource_id,
    where: [resource_type: :album],
    on_delete: :delete_all
  ]

  schema "albums" do
    field :name, :string
    field :password, :string
    field :set_password, :boolean
    field :client_link_hash, :string
    field :is_proofing, :boolean, default: false
    field :is_finals, :boolean, default: false
    belongs_to(:gallery, Gallery)
    belongs_to(:thumbnail_photo, Photo, on_replace: :nilify)
    has_many(:photos, Photo)
    has_many(:session_tokens, SessionToken, @session_opts)

    timestamps(type: :utc_datetime)
  end

  @attrs [:name, :set_password, :gallery_id, :password, :is_proofing, :is_finals, :client_link_hash]
  @required_attrs [:name, :set_password, :gallery_id]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> validate_name()
  end

  def update_changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> validate_name()
  end

  def password_changeset(album, attrs \\ %{}) do
    album
    |> cast(attrs, [:password])
    |> validate_required([:password])
  end

  def update_thumbnail(album, photo) do
    album |> change() |> put_assoc(:thumbnail_photo, photo)
  end

  defp validate_name(changeset),
    do: validate_length(changeset, :name, max: 35)
end
