defmodule Picsello.Galleries.Photo do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Album, Gallery}

  schema "photos" do
    field :client_liked, :boolean, default: false
    field :name, :string
    field :original_url, :string
    field :position, :float
    field :preview_url, :string
    field :watermarked_url, :string
    field :watermarked_preview_url, :string
    field :aspect_ratio, :float

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
    :watermarked_preview_url,
    :client_liked,
    :gallery_id,
    :album_id,
    :aspect_ratio
  ]
  @update_attrs [
    :name,
    :position,
    :preview_url,
    :watermarked_url,
    :watermarked_preview_url,
    :client_liked,
    :aspect_ratio
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
