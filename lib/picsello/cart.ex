defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  import Ecto.Query

  alias Picsello.{
    Repo,
    WHCC,
    Cart.CartProduct,
    Cart.DeliveryInfo,
    Cart.Order,
    Cart.Order.Digital,
    Cart.OrderNumber,
    Galleries,
    Galleries.Gallery
  }

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
  Puts the product or digital in the cart.
  """
  def place_product(product, gallery_id) do
    params = %{gallery_id: gallery_id}

    case get_unconfirmed_order(gallery_id) do
      {:ok, order} -> place_product_in_order(order, product, params)
      {:error, _} -> create_order_with_product(product, params)
    end
  end

  def contains_digital?(%Order{digitals: digitals}, photo_id) when is_integer(photo_id),
    do:
      Enum.any?(
        digitals,
        &(Map.get(&1, :photo_id) == photo_id)
      )

  def contains_digital?(nil, _), do: false

  def contains_digital?(gallery_id, photo_id) do
    case(get_unconfirmed_order(gallery_id)) do
      {:ok, order} -> contains_digital?(order, photo_id)
      _ -> false
    end
  end

  @doc """
  Deletes the product from order. Deletes order if order has only the one product.
  """
  def delete_product(%Order{} = order, editor_id) do
    case item_count(order) do
      1 ->
        order |> Repo.delete!()

      _ ->
        order
        |> Order.delete_product_changeset(editor_id)
        |> Repo.update!()
    end
    |> order_with_state()
  end

  defp order_with_state(%Order{__meta__: %Ecto.Schema.Metadata{state: state}} = order),
    do: {state, order}

  @doc """
  Gets the current order for gallery.
  """
  def get_unconfirmed_order(gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and not order.placed
    )
    |> Repo.one()
    |> case do
      %Order{} = order -> {:ok, order}
      _ -> {:error, :no_unconfirmed_order}
    end
  end

  def get_unconfirmed_order(gallery_id, :preload_products) do
    case get_unconfirmed_order(gallery_id) do
      {:ok, %{products: [_ | _] = products} = order} ->
        ids = for(%{editor_details: %{product_id: id}} <- products, do: id)

        products_by_whcc_id =
          from(product in Picsello.Product, where: product.whcc_id in ^ids)
          |> Repo.all()
          |> Enum.map(&{&1.whcc_id, &1})
          |> Map.new()

        {:ok,
         %{
           order
           | products:
               for(
                 %{editor_details: %{product_id: id}} = product <- products,
                 do: %{product | whcc_product: Map.get(products_by_whcc_id, id)}
               )
         }}

      error ->
        error
    end
  end

  def get_placed_gallery_order!(%{id: gallery_id}, order_number) do
    order_id = order_number |> OrderNumber.from_number()

    from(order in Order,
      where:
        order.gallery_id == ^gallery_id and not is_nil(order.placed_at) and order.id == ^order_id
    )
    |> Repo.one!()
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
  def confirm_order(
        %Gallery{id: gallery_id} = gallery,
        order_number,
        stripe_session_id
      ) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:order, fn repo, _ ->
      order_id = OrderNumber.from_number(order_number)

      order =
        from(order in Order,
          join: gallery in assoc(order, :gallery),
          join: job in assoc(gallery, :job),
          join: client in assoc(job, :client),
          join: organization in assoc(client, :organization),
          where: gallery.id == ^gallery_id and order.id == ^order_id,
          preload: [gallery: {gallery, job: {job, client: {client, organization: organization}}}]
        )
        |> repo.one!()

      {:ok, order}
    end)
    |> Ecto.Multi.run(:confirmed, fn _, %{order: %{placed_at: placed_at}} ->
      case placed_at do
        %DateTime{} -> {:error, true}
        nil -> {:ok, false}
      end
    end)
    |> Ecto.Multi.run(:stripe, fn _,
                                  %{
                                    order: %{
                                      gallery: %{
                                        job: %{
                                          client: %{
                                            organization: %{stripe_account_id: stripe_account_id}
                                          }
                                        }
                                      }
                                    }
                                  } ->
      case Picsello.Payments.retrieve_session(stripe_session_id,
             connect_account: stripe_account_id
           ) do
        {:ok,
         %{payment_status: "paid", client_reference_id: "order_number_" <> ^order_number} =
             session} ->
          {:ok, session}

        {:ok, session} ->
          {:error, "unexpected session #{inspect(session)}"}

        error ->
          error
      end
    end)
    |> Ecto.Multi.run(:confirm, fn repo, %{order: %{products: products} = order} ->
      confirmed_products =
        products
        |> Task.async_stream(fn %CartProduct{whcc_order: %{confirmation: confirmation}} = product ->
          confirmation = gallery |> Galleries.account_id() |> WHCC.confirm_order(confirmation)

          CartProduct.add_confirmation(product, confirmation)
        end)
        |> Enum.to_list()

      order
      |> Order.confirmation_changeset(confirmed_products)
      |> repo.update()
    end)
    |> Repo.transaction()
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

  def set_order_number(order) do
    order
    |> Ecto.Changeset.change(number: order.id |> Picsello.Cart.OrderNumber.to_number())
    |> Repo.update!()
  end

  def item_count(%{products: products, digitals: digitals}),
    do: Enum.count(products) + Enum.count(digitals)

  def summary_counts(order) do
    for(key <- [:products, :digitals]) do
      collection = Map.get(order, key)

      {key, Enum.count(collection),
       Enum.reduce(collection, Money.new(0), &Money.add(&2, &1.price))}
    end
  end

  def checkout_params(
        %Order{products: products, digitals: digitals, shipping_cost: shipping_cost} = order
      ) do
    product_line_items =
      Enum.map(products, fn %{
                              price: price,
                              editor_details: %{
                                selections: %{"quantity" => quantity}
                              }
                            } = product ->
        unit_amount = price |> Money.divide(quantity) |> hd |> Map.get(:amount)

        %{
          price_data: %{
            currency: price.currency,
            unit_amount: unit_amount,
            product_data: %{
              name: product_name(product),
              images: [preview_url(product)]
            }
          },
          quantity: quantity
        }
      end)

    digital_line_items =
      Enum.map(digitals, fn %{price: price} = digital ->
        %{
          price_data: %{
            currency: price.currency,
            unit_amount: price.amount,
            product_data: %{
              name: "Digital image",
              images: [preview_url(digital)]
            }
          },
          quantity: 1
        }
      end)

    %{
      line_items: product_line_items ++ digital_line_items,
      customer_email: order.delivery_info.email,
      client_reference_id: "order_number_#{Order.number(order)}",
      shipping_options: [
        %{
          shipping_rate_data: %{
            type: "fixed_amount",
            display_name: "Shipping",
            fixed_amount: %{
              amount: shipping_cost.amount,
              currency: shipping_cost.currency
            }
          }
        }
      ]
    }
  end

  def product_name(%CartProduct{
        editor_details: %{selections: selections},
        whcc_product: %{whcc_name: name} = product
      }) do
    size =
      product |> Picsello.WHCC.Product.selection_details(selections) |> get_in(["size", "name"])

    Enum.join([size, name], " ")
  end

  def preview_url(%CartProduct{editor_details: %{preview_url: url}}), do: url

  def preview_url(%Digital{preview_url: path}),
    do: Picsello.Galleries.Workers.PhotoStorage.path_to_url(path)

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

  defp create_order_with_product(product, attrs) do
    product
    |> Order.create_changeset(attrs)
    |> Repo.insert!()
    |> set_order_number()
  end

  defp place_product_in_order(%Order{} = order, product, attrs) do
    order
    |> Order.update_changeset(product, attrs)
    |> Repo.update!()
  end
end
