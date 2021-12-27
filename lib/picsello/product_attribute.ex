defmodule Picsello.ProductAttribute do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "product_attributes" do
    belongs_to(:product, Picsello.Product)
    field(:variation_category_name, :string)
    field(:variation_name, :string)
    field(:variation_id, :string)
    field(:category_name, :string)
    field(:category_id, :string)
    field(:name, :string)
    field(:id, :string)
    field(:width, :integer)
    field(:height, :integer)
    field(:price, Money.Ecto.Amount.Type)
  end
end
