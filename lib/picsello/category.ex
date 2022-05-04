defmodule Picsello.Category do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  import Picsello.Package, only: [validate_money: 2]

  @preview_templates %{
    "album_transparency.png" => [800, 715, 1720, 715, 800, 1620, 1720, 1620],
    "frame_transparency.png" => [550, 550, 2110, 550, 550, 1600, 2110, 1600],
    "card_blank.png" => [0, 0, 1120, 0, 0, 1100, 1120, 1100]
  }

  schema "categories" do
    field :deleted_at, :utc_datetime
    field :hidden, :boolean
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

  def coords(category) do
    @preview_templates |> Map.get(frame_image(category))
  end

  def frame_image(%{frame_image: frame_image}), do: frame_image || "card_blank.png"
end
