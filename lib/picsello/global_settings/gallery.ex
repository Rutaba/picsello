defmodule Picsello.GlobalSettings.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Money.Sigils
  alias Picsello.{Organization, Package}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery

  defmodule Photo do
    @moduledoc false
    defstruct original_url: nil,
              organization_id: nil,
              id: nil,
              text: nil,
              is_save_preview: false,
              watermark_type: nil
  end

  @default_each_price ~M[5000]USD
  @default_buy_all_price ~M[75000]USD

  schema "global_settings_galleries" do
    field(:expiration_days, :integer, default: 0)
    field(:watermark_name, :string)
    field(:watermark_type, Ecto.Enum, values: [:image, :text])
    field(:watermark_size, :integer)
    field(:watermark_text, :string)
    field(:global_watermark_path, :string)
    field(:buy_all_price, Money.Ecto.Map.Type, default: @default_buy_all_price)
    field(:download_each_price, Money.Ecto.Map.Type, default: @default_each_price)

    belongs_to(:organization, Organization)
    timestamps()
  end

  @image_attrs [:watermark_name, :watermark_size]
  @text_attrs [:watermark_text]
  def expiration_changeset(global_settings_gallery, attrs) do
    cast(global_settings_gallery, attrs, [:expiration_days])
  end

  def price_changeset(%__MODULE__{} = global_settings_gallery, attrs \\ %{}) do
    global_settings_gallery
    |> cast(attrs, [:organization_id, :expiration_days, :buy_all_price, :download_each_price])
    |> validate_required([:download_each_price])
    |> then(fn changeset ->
      if Map.get(attrs, "status") !== :unlimited do
        changeset
        |> Package.validate_money(:download_each_price,
          greater_than: 200,
          message: "must be greater than two"
        )
      else
        changeset
      end
    end)
    |> then(fn changeset ->
      each_price = get_field(changeset, :download_each_price) || Money.new(0)

      changeset
      |> Package.validate_money(:buy_all_price,
        greater_than: each_price.amount,
        message: "must be greater than each price"
      )
    end)
    |> then(fn changeset ->
      buy_all_price = get_field(changeset, :buy_all_price) || Money.new(0)

      changeset
      |> Package.validate_money(:download_each_price,
        less_than: buy_all_price.amount,
        message: "must be less than buy all price"
      )
    end)
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
    |> put_change(:watermark_type, :image)
    |> validate_required(@image_attrs)
    |> nilify_fields(@text_attrs)
  end

  def watermark_text_changeset(global_settings_gallery, attrs) do
    global_settings_gallery
    |> cast(attrs, @text_attrs)
    |> put_change(:watermark_type, :text)
    |> validate_required(@text_attrs)
    |> validate_length(:watermark_text, min: 3, max: 30)
    |> nilify_fields(@image_attrs)
  end

  def default_each_price(), do: @default_each_price
  def default_buy_all_price(), do: @default_buy_all_price

  def explode_days(expiration_days) do
    year = trunc(expiration_days / 365)
    month = trunc((expiration_days - year * 365) / 30)
    day = trunc(expiration_days - year * 365 - month * 30)
    {day, month, year}
  end

  def calculate_expiry_date(total_days, date \\ DateTime.utc_now()) do
    {days, months, years} = explode_days(total_days)

    Timex.shift(date, years: years)
    |> Timex.shift(months: months)
    |> Timex.shift(days: days)
  end

  def watermarked_path(),
    do: "picsello/temp/watermarked/#{UUID.uuid4()}"

  def watermark_path(id), do: "global_settings/#{id}/watermark.png"

  defp nilify_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn key, changeset -> put_change(changeset, key, nil) end)
  end

  def watermark_fields() do
    @image_attrs ++ @text_attrs ++ [:watermark_type, :global_watermark_path]
  end
end
