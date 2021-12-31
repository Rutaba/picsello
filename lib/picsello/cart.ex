defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  alias Picsello.WHCC
  alias Picsello.Cart.CartProduct

  def new_product(editor_id, account_id) do
    details = WHCC.editor_details(account_id, editor_id)
    export = WHCC.editor_export(account_id, editor_id)

    %{"totalOrderBasePrice" => raw_price, "code" => "USD"} = export.pricing
    base_price = Money.new(trunc(raw_price * 100), :USD)
    price = WHCC.mark_up_price(details, base_price)

    CartProduct.new(details, price, base_price)
  end

  @doc """
  Creates order on WHCC side

  Requires following options
     - ship_to - map with address where to deliver product to
     - return_to - map with address where to return product if not delivered
     - attributes - list with WHCC attributes. Can be used tto selecccct shipping options
  """
  def order_product(product, account_id, opts) do
    created_order = WHCC.create_order(account_id, product.editor_details.editor_id, opts)

    product
    |> CartProduct.add_order(created_order)
  end

  def confirm_product(
        %CartProduct{whcc_order: %{confirmation: confirmation}} = product,
        account_id
      ) do
    confirmation = WHCC.confirm_order(account_id, confirmation)

    product
    |> CartProduct.add_confirmation(confirmation)
  end

  @doc "stores processing info in product it finds"
  def store_cart_product_processing(
        %{"ConfirmationId" => _confirmation, "EntryId" => _entry_id, "Reference" => _ref} =
          _params
      ) do
    :todo
  end

  @doc "stores processing info in product it finds"
  def store_cart_product_tracking(
        %{"ConfirmationId" => _confirmation, "EntryId" => _entry_id, "Reference" => _ref} =
          _params
      ) do
    :todo
  end
end
