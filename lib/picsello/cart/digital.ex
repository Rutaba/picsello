defmodule Picsello.Cart.Digital do
  @moduledoc false
  use Ecto.Schema

  schema "digital_line_items" do
    belongs_to :photo, Picsello.Galleries.Photo
    belongs_to :order, Picsello.Cart.Order
    field :price, Money.Ecto.Map.Type
    field :is_credit, :boolean, default: false
    field :preview_url, :string, virtual: true
    field :currency, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          photo: Ecto.Association.NotLoaded.t() | Picsello.Galleries.Photo.t(),
          order: Ecto.Association.NotLoaded.t() | Picsello.Cart.Order.t(),
          price: Money.t(),
          is_credit: boolean(),
          preview_url: nil | String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def charged_price(%__MODULE__{is_credit: true, currency: currency}), do: Money.new(0, currency)
  def charged_price(%__MODULE__{is_credit: false, price: price}), do: price
end
