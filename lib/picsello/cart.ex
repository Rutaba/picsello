defmodule Picsello.Cart do
  @moduledoc """
  Context for cart related functions
  """

  import Ecto.Query

  alias Picsello.{
    Cart.CartProduct,
    Cart.DeliveryInfo,
    Cart.Digital,
    Cart.Order,
    Cart.OrderNumber,
    Galleries.Gallery,
    Galleries.Photo,
    Repo,
    WHCC
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

  def digital_status(gallery, photo) do
    cond do
      digital_purchased?(gallery, photo) -> :purchased
      contains_digital?(gallery, photo) -> :in_cart
      true -> :available
    end
  end

  def digital_credit(%{id: gallery_id}) do
    download_count =
      from(gallery in Gallery,
        join: job in assoc(gallery, :job),
        join: package in assoc(job, :package),
        where: gallery.id == ^gallery_id,
        select: package.download_count
      )
      |> Repo.one()

    digital_count =
      from(order in Order,
        join: digital in assoc(order, :digitals),
        where: order.gallery_id == ^gallery_id and digital.price == 0
      )
      |> Repo.aggregate(:count)

    download_count - digital_count
  end

  defp contains_digital?(%Order{digitals: digitals}, %{id: photo_id}) when is_integer(photo_id),
    do:
      Enum.any?(digitals, fn
        %{photo: %{id: id}} ->
          id == photo_id

        %{photo_id: photo_fk} ->
          photo_fk == photo_id
      end)

  defp contains_digital?(%{id: gallery_id}, photo) do
    case(get_unconfirmed_order(gallery_id)) do
      {:ok, order} -> contains_digital?(order, photo)
      _ -> false
    end
  end

  defp contains_digital?(_, _), do: false

  defp digital_purchased?(%{id: gallery_id}, %{id: photo_id}) do
    from(order in Order,
      join: digital in assoc(order, :digitals),
      where:
        order.gallery_id == ^gallery_id and not is_nil(order.placed_at) and
          digital.photo_id == ^photo_id
    )
    |> Repo.exists?()
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
      where: order.gallery_id == ^gallery_id and is_nil(order.placed_at),
      preload: [digitals: :photo]
    )
    |> Repo.one()
    |> case do
      %Order{} = order -> {:ok, order}
      _ -> {:error, :no_unconfirmed_order}
    end
  end

  def get_unconfirmed_order(gallery_id, :preload_products) do
    case get_unconfirmed_order(gallery_id) do
      {:ok, order} ->
        {:ok, order |> preload_products()}

      error ->
        error
    end
  end

  def preload_products([_ | _] = orders) do
    products = Enum.flat_map(orders, &Map.get(&1, :products, []))
    ids = for(%{editor_details: %{product_id: id}} <- products, do: id)

    products_by_whcc_id =
      from(product in Picsello.Product, where: product.whcc_id in ^ids)
      |> Repo.all()
      |> Enum.map(&{&1.whcc_id, &1})
      |> Map.new()

    for(order <- orders) do
      %{
        order
        | products:
            for(
              %{editor_details: %{product_id: id}} = product <- products,
              do: %{product | whcc_product: Map.get(products_by_whcc_id, id)}
            )
      }
    end
  end

  def preload_products(%{products: [_ | _]} = order) do
    [order] |> preload_products |> hd
  end

  def preload_products(order), do: order

  def get_placed_gallery_order!(gallery, order_number),
    do: gallery |> placed_order_query(order_number) |> preload(digitals: :photo) |> Repo.one!()

  @spec get_purchased_photos!(String.t(), %{client_link_hash: String.t()}) ::
          %{organization: %Picsello.Organization{}, photos: [%Photo{}]}
  def get_purchased_photos!(order_number, %{client_link_hash: gallery_hash} = gallery) do
    photos =
      gallery
      |> placed_order_query(order_number)
      |> join(
        :inner,
        [order: order],
        digital in assoc(order, :digitals),
        as: :digital
      )
      |> join(:inner, [digital: digital, gallery: gallery], photo in assoc(digital, :photo),
        on: photo.id == digital.photo_id and photo.gallery_id == gallery.id,
        as: :photo
      )
      |> select([photo: photo], photo)
      |> some!()

    %{
      organization:
        from(gallery in Gallery,
          join: org in assoc(gallery, :organization),
          where: gallery.client_link_hash == ^gallery_hash,
          select: org
        )
        |> Repo.one!(),
      photos: photos
    }
  end

  defp some!(query),
    do:
      query
      |> Repo.all()
      |> (case do
            [] -> raise Ecto.NoResultsError, queryable: query
            some -> some
          end)

  defp placed_order_query(%{client_link_hash: gallery_hash}, order_number) do
    order_id = OrderNumber.from_number(order_number)

    from(order in Order,
      as: :order,
      join: gallery in assoc(order, :gallery),
      as: :gallery,
      where:
        gallery.client_link_hash == ^gallery_hash and not is_nil(order.placed_at) and
          order.id == ^order_id
    )
  end

  def get_orders(gallery_id) do
    from(order in Order,
      where: order.gallery_id == ^gallery_id and not is_nil(order.placed_at),
      order_by: [desc: order.placed_at],
      preload: [digitals: :photo]
    )
    |> Repo.all()
    |> preload_products()
  end

  def order_with_editor(editor_id) do
    arg = %{id: editor_id}

    from(order in Order,
      where:
        fragment(
          ~s|jsonb_path_exists(?, '$[*] \\? (@.editor_details.editor_id == $id)', ?)|,
          order.products,
          ^arg
        ),
      preload: [digitals: :photo]
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

  def item_count(%{products: products} = order),
    do:
      [
        products,
        order
        |> Repo.preload(:digitals)
        |> Map.get(:digitals)
      ]
      |> Enum.map(&Enum.count/1)
      |> Enum.sum()

  def checkout_params(%Order{products: products, digitals: digitals} = order) do
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
              images: [preview_url(product, :watermarked)]
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
              images: [preview_url(digital, :watermarked)]
            }
          },
          quantity: 1
        }
      end)

    shipping_cost = shipping_cost(order)

    %{
      line_items: product_line_items ++ digital_line_items,
      customer_email: order.delivery_info.email,
      client_reference_id: "order_number_#{Order.number(order)}",
      payment_intent_data: %{capture_method: :manual},
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

  def preview_url(item, mode \\ nil)

  # we should be passing the watermarked version to whcc so their preview should already be watermarked
  def preview_url(%CartProduct{editor_details: %{preview_url: url}}, _mode), do: url

  def preview_url(
        %Digital{photo: %{watermarked_preview_url: watermarked_path}} = photo,
        :watermarked
      ) do
    case watermarked_path do
      nil -> preview_url(photo, nil)
      path -> Picsello.Galleries.Workers.PhotoStorage.path_to_url(path)
    end
  end

  def preview_url(%Digital{photo: %{preview_url: path}}, _mode),
    do: Picsello.Galleries.Workers.PhotoStorage.path_to_url(path)

  defdelegate confirm_order(session), to: __MODULE__.Confirmations

  defdelegate confirm_order(order_number, stripe_session_id),
    to: __MODULE__.Confirmations

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

  defdelegate total_cost(order), to: Order
  defdelegate subtotal_cost(order), to: Order
  defdelegate shipping_cost(order), to: Order
end
