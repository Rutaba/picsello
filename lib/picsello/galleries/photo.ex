defmodule Picsello.Galleries.Photo do
  @moduledoc false
  use Ecto.Schema
  use StructAccess
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.Album

  schema "photos" do
    field :client_liked, :boolean, default: false
    field :name, :string
    field :original_url, :string
    field :position, :float
    field :preview_url, :string
    field :watermarked_url, :string
    field :watermarked_preview_url, :string
    field :aspect_ratio, :float
    field :height, :integer
    field :width, :integer
    field :watermarked, :boolean, virtual: true
    field :active, :boolean, default: true

    belongs_to(:gallery, Gallery)
    belongs_to(:album, Album)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          gallery_id: integer(),
          id: integer(),
          album_id: integer() | nil,
          gallery: Gallery.t()
        }

  @create_attrs [
    :name,
    :position,
    :original_url,
    :preview_url,
    :watermarked_url,
    :watermarked_preview_url,
    :client_liked,
    :gallery_id,
    :album_id,
    :aspect_ratio,
    :active
  ]
  @update_attrs [
    :name,
    :position,
    :preview_url,
    :watermarked_url,
    :watermarked_preview_url,
    :client_liked,
    :aspect_ratio,
    :height,
    :width,
    :album_id,
    :active
  ]
  @required_attrs [:name, :position, :gallery_id, :original_url]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @create_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(%__MODULE__{} = photo, attrs \\ %{}) do
    photo
    |> cast(attrs, @update_attrs)
    |> validate_required(@required_attrs)
  end

  def original_path(name, gallery_id, uuid),
    do: "galleries/#{gallery_id}/original/#{uuid}#{Path.extname(name)}"

  def original_path(%__MODULE__{name: name, gallery_id: gallery_id}),
    do: "galleries/#{gallery_id}/original/#{UUID.uuid4()}#{Path.extname(name)}"

  def preview_path(%__MODULE__{name: name, gallery_id: gallery_id}),
    do: "galleries/#{gallery_id}/preview/#{UUID.uuid4()}#{Path.extname(name)}"

  def watermarked_path(%__MODULE__{name: name, gallery_id: gallery_id}),
    do: "galleries/#{gallery_id}/watermarked/#{UUID.uuid4()}#{Path.extname(name)}"

  def watermarked_preview_path(%__MODULE__{name: name, gallery_id: gallery_id}),
    do: "galleries/#{gallery_id}/watermarked_preview/#{UUID.uuid4()}#{Path.extname(name)}"
end
