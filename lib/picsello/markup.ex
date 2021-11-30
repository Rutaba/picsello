defmodule Picsello.Markup do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @default_markup 100.0

  schema "markups" do
    belongs_to(:organization, Picsello.Organization)
    belongs_to(:product, Picsello.Product)
    field(:whcc_attribute_id, :string)
    field(:whcc_attribute_category_id, :string)
    field(:whcc_variation_id, :string)
    field(:value, :float)

    timestamps()
  end

  @doc false
  def changeset(markup, attrs) do
    markup
    |> cast(
      attrs,
      ~w[organization_id product_id whcc_attribute_category_id whcc_variation_id whcc_attribute_id value]a
    )
    |> validate_required(
      ~w[organization_id product_id whcc_attribute_category_id whcc_variation_id whcc_attribute_id value]a
    )
    |> validate_number(:value, greater_than_or_equal_to: 0)
  end

  def default_markup, do: @default_markup
end
