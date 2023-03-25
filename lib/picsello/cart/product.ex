defmodule Picsello.Cart.Product do
  @moduledoc """
    line items of customized whcc products
  """

  import Ecto.Changeset
  import Money.Sigils

  use Ecto.Schema

  @shipping_types [values: ~w(economy 3_days 1_day)]

  schema "product_line_items" do
    field :editor_id, :string
    field :preview_url, :string
    field :quantity, :integer
    field :round_up_to_nearest, :integer
    field :selections, :map
    field :shipping_base_charge, Money.Ecto.Amount.Type
    field :shipping_type, :string, @shipping_types
    field :shipping_upcharge, :decimal
    field :unit_markup, Money.Ecto.Amount.Type
    field :total_markuped_price, Money.Ecto.Amount.Type
    field :unit_price, Money.Ecto.Amount.Type

    # recalculate for all items in cart on add or remove or edit of any product in cart
    field :print_credit_discount, Money.Ecto.Amount.Type, default: ~M[0]USD
    field :volume_discount, Money.Ecto.Amount.Type

    field :price, Money.Ecto.Amount.Type

    belongs_to :order, Picsello.Cart.Order
    belongs_to :whcc_product, Picsello.Product

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          editor_id: String.t(),
          preview_url: String.t(),
          quantity: integer(),
          round_up_to_nearest: integer(),
          selections: %{String.t() => any()},
          shipping_base_charge: Money.t(),
          shipping_upcharge: Decimal.t(),
          unit_markup: Money.t(),
          unit_price: Money.t(),
          print_credit_discount: Money.t(),
          volume_discount: Money.t(),
          price: Money.t(),
          order: Ecto.Association.NotLoaded.t() | Picsello.Cart.Order.t(),
          whcc_product: Ecto.Association.NotLoaded.t() | Picsello.Product.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def changeset(
        product,
        %__MODULE__{whcc_product_id: nil, whcc_product: %{id: whcc_product_id}} = attrs
      )
      when is_integer(whcc_product_id) do
    changeset(product, %{attrs | whcc_product_id: whcc_product_id})
  end

  def changeset(product, %__MODULE__{} = attrs), do: changeset(product, Map.from_struct(attrs))

  def changeset(product, attrs),
    do:
      cast(
        product,
        attrs,
        ~w[editor_id preview_url quantity round_up_to_nearest selections shipping_base_charge shipping_upcharge shipping_type unit_markup unit_price print_credit_discount volume_discount price whcc_product_id total_markuped_price]a
      )

  def new(fields) do
    %__MODULE__{round_up_to_nearest: 100} |> Map.merge(fields)
  end

  def charged_price(%__MODULE__{
        print_credit_discount: print_credit_discount,
        volume_discount: volume_discount,
        price: price
      }) do
    Money.subtract(price, Money.add(print_credit_discount, volume_discount))
  end

  def example_price(product), do: price(product)

  @doc "merges values for price, volume_discount, and print_credit_discount"
  def update_price(%__MODULE__{} = product, opts \\ []) do
    {credit, _opts} = Keyword.pop(opts, :credits, ~M[0]USD)
    price = price(product)

    %{
      product
      | price: price,
        volume_discount: Money.new(0),
        print_credit_discount:
          case Money.cmp(credit, price) do
            :lt -> credit
            _ -> price
          end
    }
  end

  def price(%__MODULE__{unit_price: unit_price, unit_markup: unit_markup} = product) do
    unit_price
    |> Money.add(unit_markup)
    |> Money.multiply(quantity(product))
  end

  def quantity(%__MODULE__{quantity: quantity}), do: quantity
end
