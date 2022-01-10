defmodule Picsello.Cart.CartProduct do
  @moduledoc """
  Structure/schema to hold product related info
  """

  use Ecto.Schema

  alias Picsello.WHCC

  @primary_key false
  embedded_schema do
    field :editor_details, WHCC.Editor.Details.Type
    field :base_price, Money.Ecto.Amount.Type
    field :price, Money.Ecto.Amount.Type
    field :whcc_order, WHCC.Order.Created.Type
    field :whcc_confirmation, :string
    field :whcc_processing, :map
    field :whcc_tracking, :map
  end

  def new(details, price, base_price) do
    %__MODULE__{
      editor_details: details,
      price: price,
      base_price: base_price
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

  def add_processing(%__MODULE__{} = product, processing) do
    %{product | whcc_processing: processing}
  end
end
