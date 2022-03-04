defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  import Ecto.Query
  alias Picsello.Repo
  alias Picsello.WHCC
  alias Picsello.Cart.CartProduct
  alias Picsello.Cart.Order
  alias Picsello.Cart.DeliveryInfo

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

  @doc "stores checkout info in order it finds"
  def store_cart_products_checkout(
        [%CartProduct{editor_details: %{editor_id: editor_id}} | _] = products
      ) do
    editor_id
    |> order_with_editor()
    |> Order.checkout_changeset(products)
    |> Repo.update!()
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

  @doc """
  Deletes the product from order. Deletes order if order has only the one product.
  """
  def delete_product(%Order{products: [_product]} = order, _editor_id) do
    order
    |> Repo.delete!()
    |> order_with_state()
  end

  def delete_product(%Order{} = order, editor_id) do
    order
    |> Order.delete_product_changeset(editor_id)
    |> Repo.update!()
    |> order_with_state()
  end

  defp order_with_state(%Order{__meta__: %Ecto.Schema.Metadata{state: state}} = order),
    do: {state, order}

  @doc """
  Gets the current order for gallery.
  """
  def get_unconfirmed_order(gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and order.placed == false
    )
    |> Repo.one()
    |> case do
      %Order{} = order -> {:ok, order}
      _ -> {:error, :no_unconfirmed_order}
    end
  end

  def get_placed_gallery_order(order_id, gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and order.placed == true and order.id == ^order_id
    )
    |> Repo.one()
  end

  def get_orders(gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and order.placed == true,
      order_by: [desc: order.id]
    )
    |> Repo.all()
  end

  @doc """
  Confirms the order.
  """
  def confirm_order(%Order{products: products} = order, account_id) do
    confirmed_products =
      Enum.map(products, fn product -> confirm_product(product, account_id) end)

    order
    |> Order.confirmation_changeset(confirmed_products)
    |> Repo.update!()
  end

  def order_with_editor(editor_id) do
    arg = %{id: editor_id}

    from(order in Order,
      where:
        fragment(
          ~s|jsonb_path_exists(?, '$[*] \\? (@.editor_details.editor_id == $id)', ?)|,
          order.products,
          ^arg
        )
    )
    |> Repo.one()
  end

  def delivery_info_address_states(), do: DeliveryInfo.Address.states()

  def delivery_info_selected_state(delivery_info_change) do
    DeliveryInfo.selected_state(delivery_info_change)
  end

  def delivery_info_change(attrs \\ %{}) do
    DeliveryInfo.changeset(%DeliveryInfo{}, attrs)
  end

  def order_delivery_info_change(%Order{delivery_info: delivery_info}, attrs \\ %{}) do
    DeliveryInfo.changeset(delivery_info, attrs)
  end

  def store_order_delivery_info(%Order{} = order, delivery_info_change) do
    order
    |> Order.store_delivery_info(delivery_info_change)
    |> Repo.update!()
  end

  defp seek_and_map(editor_id, fun) do
    with order <- order_with_editor(editor_id),
         true <- order != nil and is_list(order.products),
         {[target], rest} <-
           Enum.split_with(order.products, &(&1.editor_details.editor_id == editor_id)),
         true <- target != nil do
      order
      |> Order.change_products([fun.(target) | rest])
      |> Repo.update()
    else
      _ -> :ignored
    end
  end

  defp create_order_with_product(%CartProduct{} = product, attrs) do
    product
    |> Order.create_changeset(attrs)
    |> Repo.insert!()
    |> set_order_number()
  end

  defp place_product_in_order(%Order{} = order, %CartProduct{} = product, attrs) do
    order
    |> Order.update_changeset(product, attrs)
    |> Repo.update!()
  end

  def set_order_number(order) do
    order
    |> Ecto.Changeset.change(number: order.id |> Picsello.Cart.OrderNumber.to_number())
    |> Repo.update!()
  end
end
