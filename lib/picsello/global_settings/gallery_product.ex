defmodule Picsello.GlobalSettings.GalleryProduct do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.Organization
  alias Picsello.GlobalSettings.PrintProduct

  schema "global_settings_gallery_products" do
    field(:sell_product_enabled, :boolean, default: true)
    field(:product_preview_enabled, :boolean, default: true)
    field(:markup, :decimal, default: Decimal.new(0))

    belongs_to(:category, Picsello.Category)
    belongs_to(:organization, Organization)

    has_many :global_settings_print_products, PrintProduct,
      foreign_key: :global_settings_gallery_product_id

    timestamps()
  end

  def changeset(gs_gallery_product \\ %__MODULE__{}, attrs) do
    gs_gallery_product
    |> cast(attrs, [
      :sell_product_enabled,
      :product_preview_enabled,
      :markup,
      :organization_id,
      :category_id
    ])
    |> cast_assoc(:global_settings_print_products, with: &PrintProduct.changeset/2)
    |> validate_required([:category_id])
  end
end
