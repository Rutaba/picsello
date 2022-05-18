defmodule Picsello.Cart.Product do
  @moduledoc """
    line items of customized whcc products
  """

  import Money.Sigils

  use Ecto.Schema

  schema "product_line_items" do
    field :editor_id, :string
    field :preview_url, :string
    field :quantity, :integer
    field :round_up_to_nearest, :integer
    field :selections, :map
    field :shipping_base_charge, Money.Ecto.Amount.Type
    field :shipping_upcharge, :decimal
    field :unit_markup, Money.Ecto.Amount.Type
    field :unit_price, Money.Ecto.Amount.Type

    # recalculate for all items in cart on add or remove or edit of any product in cart
    field :print_credit_discount, Money.Ecto.Amount.Type, default: ~M[0]USD
    field :volume_discount, Money.Ecto.Amount.Type, default: ~M[0]USD

    field :price, Money.Ecto.Amount.Type

    belongs_to :order, Picsello.Cart.Order
    belongs_to :whcc_product, Picsello.Product

    timestamps(type: :utc_datetime)
  end

  def new(fields) do
    %__MODULE__{
      round_up_to_nearest: 500
    }
    |> Map.merge(fields)
  end

  def charged_price(%__MODULE__{
        print_credit_discount: print_credit_discount,
        volume_discount: volume_discount,
        price: price
      }) do
    Money.subtract(price, Money.add(print_credit_discount, volume_discount))
  end

  def example_price(product), do: fake_price(product)

  @doc "merges values for price and volume discount"
  def update_price(%__MODULE__{} = product, opts \\ []) do
    %{product | price: fake_price(product), volume_discount: volume_discount(product, opts)}
  end

  defp volume_discount(
         %{round_up_to_nearest: nearest, shipping_base_charge: shipping_base_charge} = product,
         opts
       ) do
    real_price =
      price(product)
      |> Money.subtract(
        if Keyword.get(opts, :shipping_base_charge) do
          0
        else
          shipping_base_charge
        end
      )
      |> round_up_to_nearest(nearest)

    Money.subtract(fake_price(product), real_price)
  end

  defp fake_price(%{round_up_to_nearest: nearest} = product) do
    %{product | quantity: 1}
    |> price()
    |> round_up_to_nearest(nearest)
    |> Money.multiply(quantity(product))
  end

  defp price(
         %__MODULE__{
           unit_markup: markup,
           unit_price: unit_price,
           shipping_upcharge: shipping_upcharge,
           shipping_base_charge: shipping_base_charge
         } = product
       ) do
    base_price = Money.multiply(unit_price, quantity(product))

    for(
      money <- [
        shipping_base_charge,
        Money.multiply(markup, quantity(product)),
        Money.multiply(base_price, shipping_upcharge)
      ],
      reduce: base_price
    ) do
      sum -> Money.add(sum, money)
    end
  end

  def quantity(%__MODULE__{quantity: quantity}), do: quantity

  defp round_up_to_nearest(money, nearest) do
    Map.update!(money, :amount, fn cents ->
      cents
      |> Decimal.new()
      |> Decimal.div(nearest)
      |> Decimal.round(0, :ceiling)
      |> Decimal.mult(nearest)
      |> Decimal.to_integer()
    end)
  end
end
