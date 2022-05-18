defmodule Picsello.Cart.Digital do
  @moduledoc false
  use Ecto.Schema
  import Money.Sigils

  schema "digital_line_items" do
    belongs_to :photo, Picsello.Galleries.Photo
    belongs_to :order, Picsello.Cart.Order
    field :price, Money.Ecto.Amount.Type
    field :is_credit, :boolean, default: false
    field :position, :integer
    field :preview_url, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  def charged_price(%__MODULE__{is_credit: true}), do: ~M[0]USD
  def charged_price(%__MODULE__{is_credit: false, price: price}), do: price
end
