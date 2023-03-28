defmodule Picsello.GlobalSettings.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Money.Sigils
  alias Picsello.Organization
  alias Picsello.GlobalSettings.Gallery, as: GSGallery

  defmodule Photo do
    @moduledoc false
    defstruct original_url: nil,
              user_id: nil,
              id: nil,
              text: nil
  end

  @default_each_price ~M[5000]USD
  @default_buy_all_price ~M[75000]USD
  
  schema "global_settings_galleries" do
    field(:expiration_days, :integer)
    field(:watermark_name, :string)
    field(:watermark_type, Ecto.Enum, values: [:image, :text])
    field(:watermark_size, :integer)
    field(:watermark_text, :string)
    field(:global_watermark_path, :string)
    field(:buy_all_price, Money.Ecto.Amount.Type, default: @default_buy_all_price)
    field(:download_each_price, Money.Ecto.Amount.Type, default: @default_each_price)

    belongs_to(:organization, Organization)
    timestamps()
  end

  @image_attrs [:watermark_name, :watermark_size]
  @text_attrs [:watermark_text]
  def expiration_changeset(global_settings_gallery, attrs) do
    global_settings_gallery
    |> cast(attrs, [:expiration_days])
  end

  def watermark_change(nil), do: change(%GSGallery{})

  def watermark_change(%GSGallery{} = global_settings_gallery),
    do: change(global_settings_gallery)

  def image_watermark_change(%GSGallery{} = global_settings_gallery, attrs),
    do: watermark_image_changeset(global_settings_gallery, attrs)

  def image_watermark_change(nil, attrs), do: watermark_image_changeset(%GSGallery{}, attrs)

  def text_watermark_change(%GSGallery{} = global_settings_gallery, attrs),
    do: watermark_text_changeset(global_settings_gallery, attrs)

  def text_watermark_change(nil, attrs), do: watermark_text_changeset(%GSGallery{}, attrs)

  def watermark_image_changeset(global_settings_gallery, attrs) do
    global_settings_gallery
    |> cast(attrs, @image_attrs)
    |> put_change(:watermark_type, "image")
    |> validate_required(@image_attrs)
    |> nilify_fields(@text_attrs)
  end

  def watermark_text_changeset(global_settings_gallery, attrs) do
    global_settings_gallery
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

  def watermark_path(id), do: "global_settings/#{id}/watermark.png"
end
