defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  alias Picsello.WHCC
  alias Picsello.Cart.CartProduct

  def new_product(editor_id, account_id) do
    details = WHCC.editor_details(account_id, editor_id)
    export = WHCC.editor_export(account_id, editor_id)
    price = WHCC.mark_up_price(details, export.pricing)

    CartProduct.new(details, price)
  end

  def order_product(product, account_id, opts) do
    created_order = WHCC.create_order(account_id, product.editor_details.editor_id, opts)

    product
    |> CartProduct.add_order(created_order)
  end
end
