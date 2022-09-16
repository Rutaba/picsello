defmodule Picsello.Category do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  import Picsello.Package, only: [validate_money: 2]

  @album %{w: 2348, h: 2331, image: "album", slot: %{x: 768, y: 710, w: 915, h: 916}}

  @preview_templates %{
    "album" => %{portrait: @album, landscape: @album},
    "frame" => %{
      portrait: %{
        image: "wooden_frame_portrait",
        w: 2157,
        h: 2652,
        slot: %{y: 558, x: 548, h: 1547, w: 1063}
      },
      landscape: %{
        image: "wooden_frame_landscape",
        w: 2652,
        h: 2157,
        slot: %{x: 558, y: 548, w: 1547, h: 1063}
      }
    },
    "envelope" => %{
      portrait: %{
        image: "envelope_portrait",
        w: 1887,
        h: 2367,
        slot: %{x: 243, y: 161, w: 1456, h: 2015}
      },
      landscape: %{
        image: "envelope_landscape",
        w: 2367,
        h: 1887,
        slot: %{w: 2015, h: 1456, x: 191, y: 243}
      }
    }
  }

  schema "categories" do
    field :deleted_at, :utc_datetime
    field :hidden, :boolean
    field :coming_soon, :boolean, default: false
    field :icon, :string
    field :name, :string
    field :position, :integer
    field :whcc_id, :string
    field :whcc_name, :string
    field :default_markup, :decimal
    field :frame_image, :string
    field :shipping_base_charge, Money.Ecto.Type
    field :shipping_upcharge, :decimal
    has_many(:products, Picsello.Product)
    has_many(:gallery_products, Picsello.Galleries.GalleryProduct)

    timestamps(type: :utc_datetime)
  end

  def frame_images(), do: Map.keys(@preview_templates)

  def active(query \\ __MODULE__),
    do: where(query, [category], is_nil(category.deleted_at))

  def shown(query \\ __MODULE__), do: where(query, [category], not category.hidden)

  def order_by_position(query \\ __MODULE__),
    do: order_by(query, [category], asc: category.position)

  def changeset(category, attrs \\ %{}) do
    category
    |> cast(attrs, [
      :default_markup,
      :coming_soon,
      :frame_image,
      :hidden,
      :icon,
      :name,
      :shipping_base_charge,
      :shipping_upcharge
    ])
    |> validate_required([
      :icon,
      :name,
      :default_markup,
      :shipping_base_charge,
      :shipping_upcharge
    ])
    |> validate_number(:default_markup, greater_than_or_equal_to: 1.0)
    |> validate_money(:shipping_base_charge)
    |> validate_number(:shipping_upcharge, greater_than_or_equal_to: 0.0)
    |> validate_inclusion(:icon, Picsello.Icon.names())
    |> validate_inclusion(:frame_image, frame_images())
    |> unique_constraint(:position)
  end

  def frame(category) do
    image = frame_image(category)

    @preview_templates
    |> Map.get(image)
    |> case do
      nil -> nil
      frame -> frame |> Map.put(:image, image)
    end
  end

  def frame_image(%{frame_image: frame_image}), do: frame_image
end
