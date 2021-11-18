defmodule Picsello.Galleries.Album do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery

  schema "albums" do
    field :name, :string
    field :position, :float
    belongs_to(:gallery, Gallery)

    timestamps(type: :utc_datetime)
  end

  @create_attrs [:name, :position, :gallery_id]
  @update_attrs [:name, :position]
  @required_attrs [:name, :position, :gallery_id]

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @create_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(album, attrs \\ %{}) do
    album
    |> cast(attrs, @update_attrs)
    |> validate_required(@required_attrs)
  end
end
