defmodule Picsello.Cart.CartProduct do
  @moduledoc """
  Structure/schema to hold product related info

  """

  use Ecto.Schema

  embedded_schema do
    field :editor_details, :map
    field :base_price, Money.Ecto.Amount.Type
    field :price, Money.Ecto.Amount.Type
    field :whcc_order, :map
    field :whcc_confirmation, :string
    field :whcc_processing, :map
    field :whcc_tracking, :map
  end

  def new(details, price) do
    %__MODULE__{
      editor_details: details,
      price: price
    }
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
end
