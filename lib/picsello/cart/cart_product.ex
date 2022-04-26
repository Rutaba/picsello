defmodule Picsello.Cart.CartProduct do
  @moduledoc """
  Structure/schema to hold product related info
  """

  use Ecto.Schema

  alias Picsello.WHCC

  @primary_key false
  embedded_schema do
    field :base_price, Money.Ecto.Amount.Type
    field :charged_price, Money.Ecto.Amount.Type
    field :created_at, :integer
    field :editor_details, WHCC.Editor.Details.Type
    field :markup, Money.Ecto.Amount.Type
    field :round_up_to_nearest, :integer
    field :shipping_base_charge, Money.Ecto.Amount.Type
    field :shipping_upcharge, :decimal
    field :whcc_confirmation, :string
    field :whcc_order, WHCC.Order.Created.Type
    field :whcc_processing, :map
    field :whcc_product, :map, virtual: true
    field :whcc_tracking, :map
  end

  def new(fields) do
    %__MODULE__{
      created_at: System.os_time(:millisecond),
      round_up_to_nearest: 500
    }
    |> Map.merge(fields)
  end

  def add_order(%__MODULE__{} = product, order) do
    %{product | whcc_order: order}
  end

  def add_confirmation(%__MODULE__{} = product, confirmation) do
    %{product | whcc_confirmation: confirmation}
  end

  def add_tracking(%__MODULE__{} = product, tracking) do
    %{product | whcc_tracking: tracking}
  end

  def add_processing(%__MODULE__{} = product, processing) do
    %{product | whcc_processing: processing}
  end

  def id(%__MODULE__{editor_details: %{editor_id: editor_id}}), do: editor_id
  def product_id(%__MODULE__{editor_details: %{product_id: product_id}}), do: product_id

  def price(
        %__MODULE__{
          markup: markup,
          base_price: base_price,
          shipping_upcharge: shipping_upcharge,
          shipping_base_charge: shipping_base_charge,
          round_up_to_nearest: nearest
        } = product,
        opts \\ []
      ) do
    shipping_upcharge = Money.multiply(base_price, shipping_upcharge)

    shipping_base_charge_multiplier =
      case Keyword.get(opts, :shipping_base_charge) do
        :no_discount -> quantity(product)
        true -> 1
        _ -> 0
      end

    for(
      money <- [
        Money.multiply(shipping_base_charge, shipping_base_charge_multiplier),
        shipping_upcharge,
        markup,
        base_price
      ],
      reduce: Money.new(0)
    ) do
      sum -> Money.add(sum, money)
    end
    |> round_to_nearest(nearest)
  end

  def quantity(%__MODULE__{editor_details: %{selections: selections}}),
    do: Map.get(selections, "quantity", 1)

  defp round_to_nearest(money, nearest) do
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
