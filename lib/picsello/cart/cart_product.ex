defmodule Picsello.Cart.CartProduct do
  @moduledoc """
  Structure/schema to hold product related info

  """

  defstruct [
    :editor_details,
    :price,
    :whcc_order,
    :whcc_confirmation,
    :whcc_tracking
  ]

  @type t :: %__MODULE__{
          editor_details: Picsello.WHCC.Editor.Details.t(),
          price: Money.t(),
          whcc_order: Picsello.WHCC.Order.Created.t() | nil,
          whcc_confirmation: atom() | {:error, any()},
          whcc_tracking: any()
        }

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
