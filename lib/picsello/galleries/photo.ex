defmodule Picsello.Galleries.Photo do
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Album, Gallery}

  schema "photos" do
    field :client_copy_url, :string
    field :client_liked, :boolean, default: false
    field :name, :string
    field :original_url, :string
    field :position, :float
    field :preview_url, :string
    field :watermarked_url, :string
    belongs_to(:gallery, Gallery)
    belongs_to(:album, Album)

    timestamps(type: :utc_datetime)
  end

  @create_attrs [
    :name,
    :position,
    :original_url,
    :preview_url,
    :watermarked_url,
    :client_copy_url,
    :client_liked,
    :gallery_id,
    :album_id
  ]
  @update_attrs [
    :name,
    :position,
    :preview_url,
    :watermarked_url,
    :client_copy_url,
    :client_liked
  ]
  @required_attrs [:name, :position, :gallery_id, :original_url]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @create_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(photo, attrs \\ %{}) do
    photo
    |> cast(attrs, @update_attrs)
    |> validate_required(@required_attrs)
  end
end
