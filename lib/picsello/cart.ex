defmodule Picsello.Cart do
  @moduledoc """
  Context for cart and order related functions
  """

  import Ecto.Query

  alias Picsello.{
    Cart.DeliveryInfo,
    Cart.Digital,
    Cart.Order,
    Cart.OrderNumber,
    Galleries,
    Galleries.Gallery,
    Galleries.Photo,
    Repo,
    WHCC
  }

  alias Picsello.Cart.Product, as: CartProduct

  def new_product(editor_id, account_id) do
    account_id |> WHCC.price_details(editor_id) |> CartProduct.new()
  end

  @doc """
  Creates order on WHCC side
  """
  def create_whcc_order(
        %Order{
          products: products,
          delivery_info: delivery_info,
          gallery_id: gallery_id
        } = order
      ) do
    editors =
      for product <- products do
        WHCC.Editor.Export.Editor.new(product.editor_id,
          order_attributes: Picsello.WHCC.Shipping.to_attributes(product)
        )
      end

    account_id = Galleries.account_id(gallery_id)

    export =
      WHCC.editors_export(account_id, editors,
        entry_id: order |> Order.number() |> to_string(),
        address: delivery_info
      )

    order
    |> Order.whcc_order_changeset(WHCC.create_order(account_id, export))
    |> Repo.update!()
  end

  @doc "stores processing info in order it finds"
  def update_whcc_order(%{entry_id: entry_id} = payload) do
    case from(order in Order,
           where: fragment("? ->> 'entry_id' = ?", order.whcc_order, ^entry_id),
           preload: [products: :whcc_product]
         )
         |> Repo.one() do
      nil ->
        {:error, "order not found"}

      order ->
        order
        |> Order.whcc_order_changeset(payload)
        |> Repo.update()
    end
  end

  @doc """
  Puts the product, digital, or bundle in the cart.
  """
  def place_product(product, gallery_id) do
    params = %{gallery_id: gallery_id}

    case get_unconfirmed_order(gallery_id, preload: [:products, :digitals]) do
      {:ok, order} -> place_product_in_order(order, product, params)
      {:error, _} -> create_order_with_product(product, params)
    end
  end

  def bundle_status(gallery) do
    cond do
      bundle_purchased?(gallery) -> :purchased
      contains_bundle?(gallery) -> :in_cart
      true -> :available
    end
  end

  def digital_status(gallery, photo) do
    cond do
      bundle_purchased?(gallery) -> :purchased
      digital_purchased?(gallery, photo) -> :purchased
      Galleries.do_not_charge_for_download?(gallery) -> :purchased
      contains_bundle?(gallery) -> :in_cart
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

  defp bundle_purchased?(%{id: gallery_id}) do
    from(order in Order,
      where:
        order.gallery_id == ^gallery_id and not is_nil(order.placed_at) and
          not is_nil(order.bundle_price)
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

  def get_placed_gallery_order!(gallery, order_number) do
    gallery
    |> placed_order_query(order_number)
    |> preload_digitals()
    |> Repo.one!()
  end

  defp preload_digitals(order_query) do
    photo_query = Picsello.Photos.watermarked_query()

    from(order in order_query,
      left_join: digital in assoc(order, :digitals),
      preload: [digitals: {digital, photo: ^photo_query}]
    )
  end

  @spec get_purchased_photos!(String.t(), %{client_link_hash: String.t()}) ::
          %{organization: %Picsello.Organization{}, photos: [%Photo{}]}
  def get_purchased_photos!(order_number, %{client_link_hash: gallery_hash} = gallery) do
    order = gallery |> placed_order_query(order_number) |> Repo.one!()

    %{
      organization: get_organization!(gallery_hash),
      photos: get_order_photos!(order)
    }
  end

  def get_purchased_photo!(gallery, photo_id) do
    if can_download_all?(gallery) do
      from(photo in Photo, where: photo.gallery_id == ^gallery.id and photo.id == ^photo_id)
      |> Repo.one!()
    else
      from(digital in Digital,
        join: order in assoc(digital, :order),
        join: photo in assoc(digital, :photo),
        where:
          order.gallery_id == ^gallery.id and digital.photo_id == ^photo_id and
            not is_nil(order.placed_at),
        select: photo
      )
      |> Repo.one!()
    end
  end

  def get_all_photos!(%{client_link_hash: gallery_hash} = gallery) do
    if can_download_all?(gallery) do
      %{
        organization: get_organization!(gallery_hash),
        photos: from(photo in Photo, where: photo.gallery_id == ^gallery.id) |> some!()
      }
    else
      raise Ecto.NoResultsError, queryable: Gallery
    end
  end

  defp get_organization!(gallery_hash) do
    from(gallery in Gallery,
      join: org in assoc(gallery, :organization),
      where: gallery.client_link_hash == ^gallery_hash,
      select: org
    )
    |> Repo.one!()
  end

  defp get_order_photos!(%Order{bundle_price: %Money{}} = order) do
    from(photo in Photo, where: photo.gallery_id == ^order.gallery_id)
    |> some!()
  end

  defp get_order_photos!(%Order{id: order_id}) do
    from(order in Order,
      join: digital in assoc(order, :digitals),
      join: photo in assoc(digital, :photo),
      where: order.id == ^order_id,
      select: photo
    )
    |> some!()
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
      order_by: [desc: order.placed_at]
    )
    |> preload_digitals()
    |> preload(products: :whcc_product)
    |> Repo.all()
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
    |> update_order_preserving_lines!()
  end

  def set_order_number(order) do
    order
    |> Ecto.Changeset.change(number: order.id |> Picsello.Cart.OrderNumber.to_number())
    |> update_order_preserving_lines!()
  end

  defp update_order_preserving_lines!(%{data: order} = changeset) do
    changeset
    |> Repo.update!()
    |> then(&Map.merge(&1, Map.take(order, [:products, :digitals])))
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

  def checkout_params(%Order{digitals: digitals, products: products} = order) do
    product_line_items =
      for line_item <- products do
        price = CartProduct.charged_price(line_item)

        %{
          price_data: %{
            currency: price.currency,
            unit_amount: price.amount,
            product_data: %{
              name: "#{product_name(line_item)} (Qty #{product_quantity(line_item)})",
              images: [item_image_url(line_item)],
              tax_code: Picsello.Payments.tax_code(:product)
            },
            tax_behavior: "exclusive"
          },
          quantity: 1
        }
      end

    digital_line_items =
      Enum.map(digitals, fn digital ->
        price = Digital.charged_price(digital)

        %{
          price_data: %{
            currency: price.currency,
            unit_amount: price.amount,
            product_data: %{
              name: "Digital image",
              images: [item_image_url(digital)],
              tax_code: Picsello.Payments.tax_code(:digital)
            },
            tax_behavior: "exclusive"
          },
          quantity: 1
        }
      end)

    bundle_line_items =
      if order.bundle_price do
        gallery = order |> Repo.preload(:gallery) |> Map.get(:gallery)

        [
          %{
            price_data: %{
              currency: order.bundle_price.currency,
              unit_amount: order.bundle_price.amount,
              product_data: %{
                name: "Bundle - all digital downloads",
                images: [item_image_url({:bundle, gallery})],
                tax_code: Picsello.Payments.tax_code(:digital)
              },
              tax_behavior: "exclusive"
            },
            quantity: 1
          }
        ]
      else
        []
      end

    %{
      line_items: product_line_items ++ digital_line_items ++ bundle_line_items,
      customer_email: order.delivery_info.email,
      client_reference_id: "order_number_#{Order.number(order)}",
      payment_intent_data: %{capture_method: :manual}
    }
  end

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

  def item_image_url(%Digital{photo: photo}), do: Picsello.Photos.preview_url(photo)

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

  defdelegate confirm_order(session, helpers), to: __MODULE__.Confirmations

  defdelegate confirm_order(order_number, stripe_session_id, helpers),
    to: __MODULE__.Confirmations

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

  defdelegate product_quantity(line_item), to: CartProduct, as: :quantity
  defdelegate total_cost(order), to: Order
  defdelegate priced_lines_by_product(order), to: Order
  defdelegate priced_lines(order), to: Order

  def price_display(%Digital{} = digital) do
    "#{if Money.zero?(digital.price), do: "1 credit - "}#{digital.price}"
  end

  def price_display({:bundle, %Order{bundle_price: price}}), do: price
  def price_display(product), do: product.price

  def has_download?(%Order{bundle_price: bundle_price, digitals: digitals}),
    do: bundle_price != nil || digitals != []

  def can_download_all?(%Gallery{} = gallery) do
    Galleries.do_not_charge_for_download?(gallery) || bundle_purchased?(gallery)
  end
end
