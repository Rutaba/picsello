defmodule Picsello.Cart do
  @moduledoc """
  Context for cart and order related functions
  """

  import Ecto.Query
  import Money.Sigils

  alias Picsello.{
    Cart.DeliveryInfo,
    Cart.Digital,
    Cart.Order,
    Galleries,
    Galleries.Gallery,
    Orders,
    Repo,
    WHCC
  }

  alias Ecto.Multi
  alias Ecto.Changeset
  alias Picsello.Cart.Product, as: CartProduct

  @default_shipping "economy"
  @products_config Application.compile_env!(:picsello, :products)
  @shipping_to_all [@products_config[:whcc_album_id], @products_config[:whcc_books_id]]

  def new_product(editor_id, gallery_id) do
    gallery_id |> WHCC.price_details(editor_id) |> CartProduct.new()
  end

  @doc """
  Puts the product, digital, or bundle in the cart.
  """
  @spec place_product(
          {:bundle, Money.t()} | CartProduct.t() | Digital.t(),
          Gallery.t() | integer(),
          integer() | nil
        ) ::
          Order.t()
  def place_product(product, gallery, album_id \\ nil)

  def place_product(product, %Gallery{id: id, use_global: use_global} = gallery, album_id) do
    opts = [credits: credit_remaining(gallery), use_global: use_global]

    order_opts = [preload: [:products, :digitals]]

    case get_unconfirmed_order(id, Keyword.put(order_opts, :album_id, album_id)) do
      {:ok, order} ->
        place_product_in_order(order, product, opts)

      {:error, _} ->
        create_order_with_product(product, %{gallery_id: id, album_id: album_id}, opts)
    end
  end

  def place_product(product, gallery_id, album_id) when is_integer(gallery_id),
    do: place_product(product, Galleries.get_gallery!(gallery_id), album_id)

  def bundle_status(gallery, album_id \\ nil) do
    cond do
      Orders.bundle_purchased?(gallery) -> :purchased
      contains_bundle?(gallery, album_id) -> :in_cart
      true -> :available
    end
  end

  def digital_status(gallery, photo, album_id \\ nil) do
    cond do
      Orders.bundle_purchased?(gallery) -> :purchased
      digital_purchased?(gallery, photo) -> :purchased
      Galleries.do_not_charge_for_download?(gallery) -> :purchased
      contains_bundle?(gallery, album_id) -> :in_cart
      contains_digital?(gallery, photo, album_id) -> :in_cart
      true -> :available
    end
  end

  def credit_remaining(%Gallery{id: gallery_id}) do
    digital_credit = digital_credit_remaining(gallery_id)
    print_credit = print_credit_remaining(gallery_id)

    if digital_credit && print_credit do
      Map.merge(digital_credit, print_credit)
    else
      %{digital: 0, print: ~M[0]USD}
    end
  end

  defp digital_credit_remaining(gallery_id) do
    from(gallery in Gallery,
      join: digital_pricing in assoc(gallery, :gallery_digital_pricing),
      left_join: orders in assoc(gallery, :orders),
      left_join: digitals in assoc(orders, :digitals),
      where: gallery.id == ^gallery_id,
      select: %{
        digital:
          digital_pricing.download_count -
            fragment("count(?) filter (where ?)", digitals.id, digitals.is_credit)
      },
      group_by: digital_pricing.download_count
    )
    |> Repo.one()
  end

  defp print_credit_remaining(gallery_id) do
    from(gallery in Gallery,
      join: digital_pricing in assoc(gallery, :gallery_digital_pricing),
      left_join: orders in assoc(gallery, :orders),
      left_join: products in assoc(orders, :products),
      where: gallery.id == ^gallery_id,
      select: %{
        print:
          type(
            coalesce(digital_pricing.print_credits, 0) -
              coalesce(sum(products.print_credit_discount), 0),
            Money.Ecto.Amount.Type
          )
      },
      group_by: digital_pricing.print_credits
    )
    |> Repo.one()
  end

  defp contains_digital?(%Order{digitals: digitals}, %{id: photo_id}, _album_id)
       when is_integer(photo_id),
       do:
         Enum.any?(digitals, fn
           %{photo: %{id: id}} ->
             id == photo_id

           %{photo_id: photo_fk} ->
             photo_fk == photo_id
         end)

  defp contains_digital?(%{id: gallery_id}, photo, album_id) do
    gallery_id
    |> get_unconfirmed_order(album_id: album_id, preload: [:digitals])
    |> case do
      {:ok, order} -> contains_digital?(order, photo, album_id)
      _ -> false
    end
  end

  defp contains_bundle?(%{id: gallery_id}, album_id) do
    case(get_unconfirmed_order(gallery_id, album_id: album_id)) do
      {:ok, order} -> order.bundle_price != nil
      _ -> false
    end
  end

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
  def delete_product(%Order{} = order, opts) do
    %{gallery: %{use_global: use_global} = gallery} =
      order = Repo.preload(order, [:gallery, :digitals, products: :whcc_product])

    opts = Keyword.merge(opts, credits: credit_remaining(gallery), use_global: use_global)

    order
    |> expire_previous_session()
    |> item_count()
    |> case do
      1 ->
        order |> Repo.delete()

      _ ->
        order
        |> Order.delete_product_changeset(opts)
        |> Repo.update()
    end
    |> case do
      {:ok, %Order{__meta__: %Ecto.Schema.Metadata{state: state}} = order} -> {state, order}
    end
  end

  @doc """
  Gets the current order for gallery.
  """
  @spec get_unconfirmed_order(integer(),
          album_id: integer(),
          preload: [:digitals | :products | :package]
        ) ::
          {:ok, Order.t()} | {:error, :no_unconfirmed_order}
  def get_unconfirmed_order(gallery_id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    for assoc <- preloads,
        fun =
          Map.get(
            %{
              products: &preload(&1, products: :whcc_product),
              digitals: &preload_digitals/1,
              package: &preload(&1, :package)
            },
            assoc
          ),
        reduce:
          Order
          |> where([order], order.gallery_id == ^gallery_id and is_nil(order.placed_at))
          |> then(
            &case Keyword.get(opts, :album_id) do
              nil -> where(&1, [order], is_nil(order.album_id))
              album_id -> where(&1, [order], order.album_id == ^album_id)
            end
          ) do
      query ->
        fun.(query)
    end
    |> Repo.one()
    |> case do
      %Order{} = order ->
        {:ok, order}

      _ ->
        {:error, :no_unconfirmed_order}
    end
  end

  def preload_products(order), do: Repo.preload(order, products: :whcc_product)

  def preload_digitals(order_query) do
    photo_query = Picsello.Photos.watermarked_query()

    from(order in order_query,
      left_join: digital in assoc(order, :digitals),
      preload: [digitals: {digital, photo: ^photo_query}]
    )
  end

  def order_with_editor(editor_id) do
    from(order in Order,
      as: :order,
      where:
        exists(
          from product in CartProduct,
            where: product.order_id == parent_as(:order).id and product.editor_id == ^editor_id
        ),
      preload: [digitals: :photo, products: :whcc_product]
    )
    |> Repo.one()
  end

  def delivery_info_address_states(), do: DeliveryInfo.Address.states()

  def delivery_info_selected_state(delivery_info_change) do
    DeliveryInfo.selected_state(delivery_info_change)
  end

  def delivery_info_change(order, attrs) do
    DeliveryInfo.changeset(%DeliveryInfo{}, attrs, order: order)
  end

  def delivery_info_change(order, delivery_info, attrs) do
    DeliveryInfo.changeset(delivery_info, attrs, order: order)
  end

  def delivery_info_change(%Order{delivery_info: delivery_info} = order) do
    DeliveryInfo.changeset(delivery_info, %{}, order: order)
  end

  def store_order_delivery_info(order, delivery_info_change) do
    order
    |> Order.store_delivery_info(delivery_info_change)
    |> update_order_preserving_lines()
  end

  defp set_order_number(order) do
    {:ok, order} =
      order
      |> Ecto.Changeset.change(number: order.id |> Picsello.Cart.OrderNumber.to_number())
      |> update_order_preserving_lines()

    order
  end

  defp update_order_preserving_lines(%{data: original_order} = changeset) do
    changeset
    |> Repo.update()
    |> case do
      {:ok, updated_order} ->
        {:ok, Map.merge(updated_order, Map.take(original_order, [:products, :digitals]))}

      err ->
        err
    end
  end

  def item_count(%{products: products, bundle_price: bundle_price} = order),
    do:
      [
        products,
        order
        |> Repo.preload(:digitals)
        |> Map.get(:digitals),
        Enum.filter([bundle_price], & &1)
      ]
      |> Enum.map(&Enum.count/1)
      |> Enum.sum()

  def product_name(
        %CartProduct{
          whcc_product: %{whcc_name: name}
        } = line_item
      ) do
    size = line_item |> product_size() |> Map.get("name")

    Enum.join([size, name], " ")
  end

  def product_size(%CartProduct{
        selections: selections,
        whcc_product: product
      }),
      do:
        product
        |> Picsello.WHCC.Product.selection_details(selections)
        |> (case do
              %{"size" => %{} = size} -> size
              _ -> %{}
            end)

  def item_image_url(%Digital{photo: photo}, opts),
    do: Picsello.Photos.preview_url(photo, opts)

  def item_image_url(item, _opts),
    do: item_image_url(item)

  def item_image_url(%CartProduct{preview_url: url}), do: url

  def item_image_url(%Digital{photo: photo}),
    do: Picsello.Photos.preview_url(photo)

  def item_image_url({:bundle, %Order{} = order}) do
    gallery = order |> Repo.preload(:gallery) |> Map.get(:gallery)
    item_image_url({:bundle, gallery})
  end

  def item_image_url({:bundle, %Gallery{id: id}}) do
    photo_query = Picsello.Photos.watermarked_query()

    photo =
      from(p in photo_query, where: p.gallery_id == ^id, order_by: p.position, limit: 1)
      |> Repo.one()

    item_image_url(%Digital{photo: photo})
  end

  defp create_order_with_product(product, attrs, opts) do
    product
    |> Order.create_changeset(attrs, opts)
    |> Repo.insert!()
    |> set_order_number()
  end

  defp expire_previous_session(order) do
    {:ok, _} = order.id |> __MODULE__.Checkouts.handle_previous_session() |> Repo.transaction()
    order
  end

  defp place_product_in_order(order, product, opts) do
    order
    |> expire_previous_session()
    |> Order.update_changeset(product, %{}, opts)
    |> Repo.update!()
  end

  def price_display(%Digital{is_credit: true}), do: "1 credit - $0.00"
  def price_display(%Digital{price: price}), do: price

  def price_display({:bundle, %Order{bundle_price: price}}), do: price
  def price_display(product), do: Money.subtract(product.price, product.volume_discount)

  def checkout(%{id: order_id} = order, opts \\ []) do
    Picsello.Orders.subscribe(order)

    opts
    |> Enum.into(%{order_id: order_id})
    |> Picsello.Workers.Checkout.new()
    |> Oban.insert()
    |> case do
      {:ok, _} -> :ok
      err -> err
    end
  end

  @shipping_fields ~w(shipping_upcharge shipping_base_charge shipping_type)a
  def update_products_shipping(multi, products) do
    Enum.reduce(products, multi, fn
      %{shipping_type: nil}, multi ->
        multi

      product, multi ->
        multi
        |> Multi.update(
          product.id,
          Changeset.change(
            Map.drop(product, @shipping_fields),
            Map.take(product, @shipping_fields)
          )
        )
    end)
    |> Repo.transaction()
  end

  @whcc_wall_art_id @products_config[:whcc_wall_art_id]
  @whcc_photo_prints_id @products_config[:whcc_photo_prints_id]
  def add_shipping_details!(product, %{shipping_type: _} = details) do
    product
    |> CartProduct.changeset(shipping_details(product, details))
    |> Repo.update!()
  end

  def shipping_details(product, %{shipping_type: shipping_type} = details) do
    shipments = details[:shipment_details] || []
    das_type = details[:das_type]

    {upcharge, shipment} = get_shipment!(product, shipping_type, shipments)

    %{
      das_carrier_cost: das_carrier_cost(shipment, das_type),
      shipping_type: shipping_type,
      shipping_upcharge: upcharge |> to_string |> Decimal.new(),
      shipping_base_charge: shipment.base_charge
    }
  end

  defp das_carrier_cost(%{das_carrier: :mail}, %{mail_cost: mail_cost}), do: mail_cost
  defp das_carrier_cost(%{das_carrier: :parcel}, %{parcel_cost: parcel_cost}), do: parcel_cost
  defp das_carrier_cost(_, _), do: Money.new(0)

  alias Picsello.Shipment.Detail

  def get_shipment!(product, shipping_type, shipments \\ []),
    do: do_get_shipment!(product, to_string(shipping_type), shipments)

  defp do_get_shipment!(
         %{
           selections: selections,
           whcc_product: %{whcc_id: whcc_id, api: %{"category" => %{"id" => category_whcc_id}}}
         },
         shipping_type,
         shipments
       ) do
    sizes =
      with %{"size" => size} <- selections do
        size
        |> String.split("x")
        |> Enum.map(&String.to_integer(&1))
      end

    shipping_type = convert_shipping_type(whcc_id, sizes, shipping_type)
    %{upcharge: upcharge} = shipment = do_get_shipment!(shipments, shipping_type)

    {upcharge(category_whcc_id, upcharge), shipment}
  end

  defp do_get_shipment!(shipments, shipping_type) do
    Enum.find(shipments, &(&1.type == shipping_type)) ||
      Repo.get_by!(Detail, type: shipping_type)
  end

  defp convert_shipping_type(@whcc_photo_prints_id, [s1, s2], "economy")
       when s1 < 9 and s2 < 13,
       do: :economy_usps

  defp convert_shipping_type(_whcc_id, _size, "economy"), do: :economy_trackable
  defp convert_shipping_type(_whcc_id, _size, "3_days"), do: :three_days
  defp convert_shipping_type(_whcc_id, _size, "1_day"), do: :one_day

  defp upcharge(@whcc_wall_art_id, upcharge), do: upcharge["wallart"]
  defp upcharge(_category_whcc_id, upcharge), do: upcharge["default"]

  def shipping_price(%{
        das_carrier_cost: das_carrier_cost,
        shipping_upcharge: shipping_upcharge,
        shipping_base_charge: shipping_base_charge,
        total_markuped_price: total_markuped_price
      }) do
    total_markuped_price
    |> Money.add(das_carrier_cost || Money.new(0))
    |> Money.multiply(Decimal.div(shipping_upcharge, 100))
    |> Money.add(shipping_base_charge)
  end

  def shipping_days(products) do
    products
    |> Enum.group_by(& &1.shipping_type)
    |> Enum.reduce([], fn
      {_k, []}, acc -> acc
      {key, _}, acc -> [choose_days(key) | acc]
    end)
    |> Enum.sort()
    |> Enum.take(2)
    |> then(fn
      [min, max] -> {min, max}
      [1] -> {1, 1}
      [min] -> {min - 1, min}
    end)
  end

  @one_day 1
  @three_days 3
  @economy 5
  defp choose_days(value) when is_atom(value), do: value |> to_string() |> choose_days()
  defp choose_days("1_day"), do: @one_day
  defp choose_days("3_days"), do: @three_days
  defp choose_days("economy"), do: @economy

  def total_shipping(%{products: [_ | _] = products}) do
    products
    |> Enum.filter(&has_shipping?/1)
    |> Enum.reduce(Money.new(0), &Money.add(&2, shipping_price(&1)))
  end

  def total_shipping(_order), do: Money.new(0)

  def has_shipping?(%{shipping_type: nil}), do: false
  def has_shipping?(_product), do: true

  def add_default_shipping_to_products(order, opts \\ %{}) do
    das_type = opts[:das_type]
    force_update = opts[:force_update]
    details = %{shipping_type: @default_shipping, das_type: das_type}

    shipping = fn p ->
      (!force_update && p.shipping_type && p) || add_shipping_details!(p, details)
    end

    order
    |> lines_by_product()
    |> Enum.map(fn
      {%{category: %{whcc_id: whcc_id}}, line_items} when whcc_id in @shipping_to_all ->
        for product <- line_items, do: shipping.(product)

      {_whcc_product, line_items} ->
        [product | products] = Enum.reverse(line_items)

        [shipping.(product) | products]
    end)
    |> Enum.concat()
  end

  defdelegate lines_by_product(order), to: Order
  defdelegate product_quantity(line_item), to: CartProduct, as: :quantity
  defdelegate total_cost(order), to: Order
end
