defmodule Picsello.GlobalSettings.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Organization
  alias Picsello.GlobalSettings.Gallery, as: GSGallery

  defmodule Photo do
    @moduledoc false
    defstruct original_url: nil,
              user_id: nil,
              id: nil,
              text: nil
  end

  @types ~w(image text)
  schema "global_settings_galleries" do
    field(:expiration_days, :integer)
    field(:watermark_name, :string)
    field(:watermark_type, :string, values: @types)
    field(:watermark_size, :integer)
    field(:watermark_text, :string)
    field(:global_watermark_path, :string)

    belongs_to(:organization, Organization)
    timestamps()
  end

  @image_attrs [:watermark_name, :watermark_size]
  @text_attrs [:watermark_text]
  def expiration_changeset(global_gallery_settings, attrs) do
    global_gallery_settings
    |> cast(attrs, [:expiration_days])
  end

  def global_gallery_watermark_change(nil),
    do: Ecto.Changeset.change(%GSGallery{})

  def global_gallery_watermark_change(%GSGallery{} = global_gallery_settings),
    do: Ecto.Changeset.change(global_gallery_settings)

  def global_gallery_image_watermark_change(
        %GSGallery{} = global_gallery_settings,
        attrs
      ),
      do: GSGallery.watermark_image_changeset(global_gallery_settings, attrs)

  def global_gallery_image_watermark_change(nil, attrs),
    do:
      GSGallery.watermark_image_changeset(
        %GSGallery{},
        attrs
      )

  def global_gallery_text_watermark_change(
        %GSGallery{} = global_gallery_settings,
        attrs
      ),
      do: GSGallery.watermark_text_changeset(global_gallery_settings, attrs)

  def global_gallery_text_watermark_change(nil, attrs),
    do:
      GSGallery.watermark_text_changeset(
        %GSGallery{},
        attrs
      )

  def watermark_image_changeset(global_gallery_settings, attrs) do
    global_gallery_settings
    |> cast(attrs, @image_attrs)
    |> put_change(:watermark_type, "image")
    |> validate_required(@image_attrs)
    |> nilify_fields(@text_attrs)
  end

  def watermark_text_changeset(global_gallery_settings, attrs) do
    global_gallery_settings
    |> cast(attrs, @text_attrs)
    |> put_change(:watermark_type, "text")
    |> validate_required(@text_attrs)
    |> validate_length(:watermark_text, min: 3, max: 30)
    |> nilify_fields(@image_attrs)
  end

  defp nilify_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn key, changeset -> put_change(changeset, key, nil) end)
  end

  def watermarked_path(),
    do: "picsello/temp/watermarked/#{UUID.uuid4()}"
end
