defmodule Picsello.Cart do
  @moduledoc """
  Context for cart and order related functions
  """

  import Ecto.Query, only: [from: 2, preload: 2]

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

  alias Picsello.Cart.Product, as: CartProduct

  def new_product(editor_id, account_id) do
    account_id |> WHCC.price_details(editor_id) |> CartProduct.new()
  end

  @doc """
  Puts the product, digital, or bundle in the cart.
  """
  @spec place_product(
          {:bundle, Money.t()} | CartProduct.t() | Digital.t(),
          %Gallery{id: integer()} | integer()
        ) ::
          Order.t()
  def place_product(product, %Gallery{id: gallery_id} = gallery) do
    opts = [credits: credit_remaining(gallery)]

    case get_unconfirmed_order(gallery_id, preload: [:products, :digitals]) do
      {:ok, order} -> place_product_in_order(order, product, opts)
      {:error, _} -> create_order_with_product(product, %{gallery_id: gallery_id}, opts)
    end
  end

  def place_product(product, gallery_id) when is_integer(gallery_id),
    do: place_product(product, %Gallery{id: gallery_id})

  def bundle_status(gallery) do
    cond do
      Orders.bundle_purchased?(gallery) -> :purchased
      contains_bundle?(gallery) -> :in_cart
      true -> :available
    end
  end

  def digital_status(gallery, photo) do
    cond do
      Orders.bundle_purchased?(gallery) -> :purchased
      digital_purchased?(gallery, photo) -> :purchased
      Galleries.do_not_charge_for_download?(gallery) -> :purchased
      contains_bundle?(gallery) -> :in_cart
      contains_digital?(gallery, photo) -> :in_cart
      true -> :available
    end
  end

  def credit_remaining(%Gallery{id: gallery_id}) do
    from(gallery in Gallery,
      join: package in assoc(gallery, :package),
      left_join: orders in assoc(gallery, :orders),
      left_join: digitals in assoc(orders, :digitals),
      left_join: products in assoc(orders, :products),
      where: gallery.id == ^gallery_id,
      select: %{
        digital:
          package.download_count -
            fragment("count(?) filter (where ?)", digitals.id, digitals.is_credit),
        print:
          type(
            coalesce(package.print_credits, 0) - coalesce(sum(products.print_credit_discount), 0),
            Money.Ecto.Amount.Type
          )
      },
      group_by: [package.download_count, package.print_credits]
    )
    |> Repo.one()
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
    gallery_id
    |> get_unconfirmed_order(preload: [:digitals])
    |> case do
      {:ok, order} -> contains_digital?(order, photo)
      _ -> false
    end
  end

  defp contains_bundle?(%{id: gallery_id}) do
    case(get_unconfirmed_order(gallery_id)) do
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
    %{gallery: gallery} =
      order = Repo.preload(order, [:gallery, :digitals, products: :whcc_product])

    order
    |> item_count()
    |> case do
      1 ->
        order |> Repo.delete()

      _ ->
        order
        |> Order.delete_product_changeset(Keyword.put(opts, :credits, credit_remaining(gallery)))
        |> Repo.update()
    end
    |> case do
      {:ok, %Order{__meta__: %Ecto.Schema.Metadata{state: state}} = order} -> {state, order}
    end
  end

  @doc """
  Gets the current order for gallery.
  """
  @spec get_unconfirmed_order(integer(), preload: [:digitals | :products | :package]) ::
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
          from(order in Order,
            where: order.gallery_id == ^gallery_id and is_nil(order.placed_at)
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

  def delivery_info_change(attrs \\ %{}) do
    DeliveryInfo.changeset(%DeliveryInfo{}, attrs)
  end

  def order_delivery_info_change(%Order{delivery_info: delivery_info}, attrs \\ %{}) do
    DeliveryInfo.changeset(delivery_info, attrs)
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

  defp place_product_in_order(order, product, opts),
    do: order |> Order.update_changeset(product, %{}, opts) |> Repo.update!()

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

  defdelegate lines_by_product(order), to: Order
  defdelegate product_quantity(line_item), to: CartProduct, as: :quantity
  defdelegate total_cost(order), to: Order
end
