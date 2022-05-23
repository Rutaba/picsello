defmodule Picsello.Cart.Product do
  @moduledoc """
    line items of customized whcc products
  """

  import Ecto.Changeset
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
    field :volume_discount, Money.Ecto.Amount.Type

    field :price, Money.Ecto.Amount.Type

    belongs_to :order, Picsello.Cart.Order
    belongs_to :whcc_product, Picsello.Product

    timestamps(type: :utc_datetime)
  end

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
        ~w[editor_id preview_url quantity round_up_to_nearest selections shipping_base_charge shipping_upcharge unit_markup unit_price print_credit_discount volume_discount price whcc_product_id]a
      )

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

  @doc "merges values for price, volume_discount, and print_credit_discount"
  def update_price(%__MODULE__{} = product, opts \\ []) do
    credit = get_in(opts, [:credits, :print]) || ~M[0]USD
    fake_price = fake_price(product)
    real_price = real_price(product, opts)

    # real_price | credit | credit_used
    # 10         | 0      | 0
    # 10         | 1      | 1
    # 10         | 11     | 10

    %{
      product
      | price: fake_price,
        volume_discount: Money.subtract(fake_price, real_price),
        print_credit_discount:
          case Money.cmp(credit, real_price) do
            :lt -> credit
            _ -> real_price
          end
    }
  end

  defp real_price(
         %{round_up_to_nearest: nearest, shipping_base_charge: shipping_base_charge} = product,
         opts
       ) do
    product
    |> price()
    |> Money.subtract(
      if Keyword.get(opts, :shipping_base_charge) do
        ~M[0]USD
      else
        shipping_base_charge
      end
    )
    |> round_up_to_nearest(nearest)
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
