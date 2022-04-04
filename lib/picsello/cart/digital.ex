defmodule Picsello.Cart.Digital do
  @moduledoc false
  use Ecto.Schema

  schema "digital_line_items" do
    belongs_to :photo, Picsello.Galleries.Photo
    belongs_to :order, Picsello.Cart.Order
    field :price, Money.Ecto.Amount.Type
    field :position, :integer
    field :preview_url, :string, virtual: true

    timestamps(type: :utc_datetime)
  end
end
