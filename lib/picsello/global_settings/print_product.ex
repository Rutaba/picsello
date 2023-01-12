defmodule Picsello.GlobalSettings.PrintProduct do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.GlobalSettings.GalleryProduct

  schema "global_settings_print_products" do
    belongs_to(:global_settings_gallery_product, GalleryProduct)
    belongs_to(:product, Picsello.Product)

    embeds_many :sizes, Size do
      field(:size, :string)
      field(:type, :string)
      field(:final_cost, :decimal)
    end

    timestamps()
  end

  def changeset(gs_gallery_product, attrs) do
    gs_gallery_product
    |> cast(attrs, [
      :global_settings_gallery_product_id,
      :product_id
    ])
    |> cast_embed(:sizes, with: &size_type_changeset/2)
    |> validate_required([:product_id])
  end

  def size_type_changeset(size_type, attrs) do
    size_type
    |> cast(attrs, [
      :size,
      :type,
      :final_cost
    ])
  end
end
