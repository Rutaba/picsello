defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  import Ecto.Query
  alias Picsello.Repo
  alias Picsello.WHCC
  alias Picsello.Cart.CartProduct
  alias Picsello.Cart.Order

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
  def store_cart_product_processing(%{"EntryId" => editor_id} = params) do
    editor_id
    |> seek_and_map(&CartProduct.add_processing(&1, params))
  end

  @doc "stores processing info in product it finds"
  def store_cart_product_tracking(%{"EntryId" => editor_id} = params) do
    editor_id
    |> seek_and_map(&CartProduct.add_tracking(&1, params))
  end

  @doc """
  Puts the product in the cart.
  """
  def place_product(%CartProduct{} = product, gallery_id) do
    params = %{gallery_id: gallery_id}

    case get_unconfirmed_order(gallery_id) do
      {:ok, order} -> place_product_in_order(order, product, params)
      {:error, _} -> create_order_with_product(product, params)
    end
  end

  def order_with_editor(editor_id) do
    from(order in Order,
      join: p in fragment("unnest(?)", order.products),
      where:
        fragment(
          "?->'editor_details'->>'editor_id' = ?",
          p,
          ^editor_id
        )
    )
    |> Repo.one()
  end

  defp seek_and_map(editor_id, fun) do
    order = editor_id |> order_with_editor()

    {[target], rest} =
      order.products
      |> Enum.split_with(fn p -> p.editor_details["editor_id"] == editor_id end)

    updated_product =
      target
      |> fun.()

    order
    |> Order.change_products([updated_product | rest])
    |> Repo.update()
  end

  defp create_order_with_product(%CartProduct{} = product, attrs) do
    product
    |> Order.create_changeset(attrs)
    |> Repo.insert!()
  end

  defp place_product_in_order(%Order{} = order, %CartProduct{} = product, attrs) do
    order
    |> Order.update_changeset(product, attrs)
    |> Repo.update!()
  end

  defp get_unconfirmed_order(gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and order.placed == false
    )
    |> Repo.one()
    |> case do
      %Order{} = product -> {:ok, product}
      _ -> {:error, :no_unconfirmed_order}
    end
  end
end
