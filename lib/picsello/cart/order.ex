defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Cart.CartProduct, Cart.DeliveryInfo, Cart.Digital, Galleries.Gallery, Repo}

  schema "gallery_orders" do
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :total_credits_amount, :integer, default: 0
    field :placed_at, :utc_datetime
    field :bundle_price, Money.Ecto.Amount.Type
    belongs_to(:gallery, Gallery)
    embeds_one :delivery_info, DeliveryInfo, on_replace: :delete
    embeds_many :products, CartProduct, on_replace: :delete
    has_one :package, through: [:gallery, :package]

    has_many :digitals, Digital, on_replace: :delete, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  def create_changeset(product, attrs \\ %{})

  def create_changeset(%CartProduct{} = product, attrs) do
    attrs
    |> do_create_changeset()
    |> put_embed(:products, [product])
  end

  def create_changeset(%Digital{} = digital, attrs) do
    attrs
    |> do_create_changeset()
    |> put_assoc(:digitals, [%{digital | position: 0}])
  end

  def create_changeset({:bundle, price}, attrs) do
    attrs
    |> do_create_changeset()
    |> put_change(:bundle_price, price)
  end

  defp do_create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:gallery_id])
    |> validate_required([:gallery_id])
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(order, product, attrs \\ %{})

  def update_changeset(order, {:bundle, price}, attrs) do
    order
    |> cast(attrs, [])
    |> put_change(:bundle_price, price)
    |> put_assoc(:digitals, [])
  end

  def update_changeset(order, %CartProduct{} = product, attrs) do
    order
    |> cast(attrs, [])
    |> replace_products([product])
  end

  def update_changeset(%__MODULE__{} = order, %Digital{} = digital, attrs) do
    order
    |> Repo.preload(:digitals)
    |> cast(attrs, [])
    |> then(fn changeset ->
      digitals = get_field(changeset, :digitals, [])

      if Enum.any?(digitals, &(&1.photo_id == digital.photo_id)) do
        changeset
      else
        put_assoc(changeset, :digitals, [
          %{
            digital
            | position: (digitals |> Enum.map(& &1.position) |> Enum.max(fn -> -1 end)) + 1
          }
          | digitals
        ])
      end
    end)
  end

  def update_changeset(changeset, %Digital{} = digital, attrs),
    do: changeset |> apply_changes() |> update_changeset(digital, attrs)

  def change_products(
        %__MODULE__{} = order,
        products,
        attrs \\ %{}
      ) do
    order
    |> cast(attrs, [])
    |> put_embed(:products, products)
  end

  def checkout_changeset(%__MODULE__{} = order, product) do
    order
    |> change()
    |> replace_products([product])
  end

  def confirmation_changeset(%__MODULE__{} = order, confirmed_products) do
    attrs = %{placed_at: DateTime.utc_now()}

    order
    |> cast(attrs, [:placed_at])
    |> put_embed(:products, confirmed_products)
  end

  def store_delivery_info(order, delivery_info_changeset) do
    order
    |> change
    |> put_embed(:delivery_info, delivery_info_changeset)
  end

  def number(%__MODULE__{id: id}), do: Picsello.Cart.OrderNumber.to_number(id)

  defp replace_products(changeset, new_products) do
    new_product_ids = Enum.map(new_products, &CartProduct.id/1)

    products_to_remain =
      changeset
      |> get_field(:products)
      |> Enum.filter(fn product -> CartProduct.id(product) not in new_product_ids end)

    products_to_store =
      (products_to_remain ++ new_products)
      |> Enum.sort(&(&1.created_at > &2.created_at))

    changeset
    |> put_embed(:products, products_to_store)
  end

  def delete_product_changeset(%__MODULE__{products: products} = order, opts) do
    case opts do
      :bundle ->
        order
        |> change()
        |> put_change(:bundle_price, nil)

      [editor_id: editor_id] ->
        order
        |> change()
        |> put_embed(
          :products,
          Enum.reject(products, &(CartProduct.id(&1) == editor_id))
        )

      [digital_id: digital_id] ->
        order = Repo.preload(order, :digitals)

        digital_to_delete = Enum.find(order.digitals, &(&1.id == digital_id))
        digitals = Enum.reject(order.digitals, &(&1.id == digital_id))

        digitals =
          if Money.zero?(digital_to_delete.price) do
            index_non_free = Enum.find_index(digitals, &Money.positive?(&1.price))

            digitals
            |> Enum.with_index()
            |> Enum.map(fn
              {digital, ^index_non_free} -> Map.put(digital, :price, Money.new(0))
              {digital, _} -> digital
            end)
          else
            digitals
          end

        order
        |> change()
        |> put_assoc(:digitals, digitals |> Enum.map(&Map.take(&1, [:id, :price])))
    end
  end

  def placed?(%__MODULE__{placed_at: nil}), do: false
  def placed?(%__MODULE__{}), do: true

  def priced_lines_by_product(order) do
    for {product, product_lines} <- line_items_by_product(order) do
      {product,
       for {product_line, index} <- Enum.with_index(product_lines) do
         %{
           line_item: product_line,
           price: CartProduct.price(product_line, shipping_base_charge: index == 0),
           price_without_discount:
             %{product_line | quantity: 1}
             |> CartProduct.price(shipping_base_charge: true)
             |> Money.multiply(CartProduct.quantity(product_line))
         }
       end}
    end
  end

  def priced_lines(order),
    do: order |> priced_lines_by_product() |> Enum.map(&elem(&1, 1)) |> List.flatten()

  def product_total(%__MODULE__{placed_at: nil} = order) do
    for %{price: price} <- priced_lines(order), reduce: Money.new(0) do
      sum -> Money.add(sum, price)
    end
  end

  def product_total(%__MODULE__{products: products}) do
    for %{charged_price: price} <- products, reduce: Money.new(0) do
      sum -> Money.add(sum, price)
    end
  end

  def digital_total(%__MODULE__{digitals: digitals, bundle_price: bundle_price}) do
    for %{price: price} <- digitals, reduce: bundle_price || Money.new(0) do
      sum -> Money.add(sum, price)
    end
  end

  def total_cost(%__MODULE__{} = order) do
    Money.add(digital_total(order), product_total(order))
  end

  defp line_items_by_product(%__MODULE__{products: products}) do
    products
    |> Enum.sort_by(&(-1 * &1.created_at))
    |> Enum.group_by(fn %{whcc_product: %Picsello.Product{} = product} -> product end)
    |> Map.to_list()
    |> Enum.sort_by(fn {_product, line_items} ->
      -1 * (line_items |> Enum.map(& &1.created_at) |> Enum.max())
    end)
  end
end
