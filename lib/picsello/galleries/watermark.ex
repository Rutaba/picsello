defmodule Picsello.Galleries.Watermark do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.Watermark

  schema "gallery_watermarks" do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:image, :text])
    field(:size, :integer)
    field(:text, :string)
    belongs_to(:gallery, Gallery)

    timestamps(type: :utc_datetime)
  end

  @image_attrs [:name, :size]
  @text_attrs [:text]

  def image_changeset(%Watermark{} = watermark, attrs) do
    watermark
    |> cast(attrs, @image_attrs)
    |> put_change(:type, :image)
    |> validate_required(@image_attrs)
    |> nilify_fields(@text_attrs)
  end

  def text_changeset(%Watermark{} = watermark, attrs) do
    watermark
    |> cast(attrs, @text_attrs)
    |> put_change(:type, :text)
    |> validate_required(@text_attrs)
    |> validate_length(:text, min: 3, max: 30)
    |> nilify_fields(@image_attrs)
  end

  defp nilify_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn key, changeset -> put_change(changeset, key, nil) end)
  end

  def build(organization_name, gallery) do
    %Watermark{type: :text, text: organization_name, gallery_id: gallery.id}
  end

  def watermark_path(id), do: "galleries/#{id}/watermark.png"
end
