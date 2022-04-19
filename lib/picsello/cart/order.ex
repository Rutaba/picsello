defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Cart.CartProduct, Cart.DeliveryInfo, Cart.Digital, Galleries.Gallery, Repo}

  schema "gallery_orders" do
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :total_credits_amount, :integer, default: 0
    field :placed_at, :utc_datetime
    belongs_to(:gallery, Gallery)
    embeds_one :delivery_info, DeliveryInfo, on_replace: :delete
    embeds_many :products, CartProduct, on_replace: :delete

    has_many :digitals, Digital, on_replace: :delete, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

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

  defp do_create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:gallery_id])
    |> validate_required([:gallery_id])
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(order, product, attrs \\ %{})

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

  def checkout_changeset(%__MODULE__{} = order, products, attrs \\ %{}) do
    order
    |> cast(attrs, [])
    |> replace_products(products)
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
    new_product_ids = Enum.map(new_products, fn product -> product.editor_details.editor_id end)

    products_to_remain =
      changeset
      |> get_field(:products)
      |> Enum.filter(fn product -> product.editor_details.editor_id not in new_product_ids end)

    products_to_store =
      (products_to_remain ++ new_products)
      |> Enum.sort(&(&1.created_at < &2.created_at))

    changeset
    |> put_embed(:products, products_to_store)
  end

  def delete_product_changeset(%__MODULE__{products: products} = order, opts) do
    case opts do
      [editor_id: editor_id] ->
        order
        |> change()
        |> put_embed(
          :products,
          Enum.reject(products, &(&1.editor_details.editor_id == editor_id))
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

  def shipping_cost(%__MODULE__{products: products}) do
    for(
      %{product: %{base_price: base_price, whcc_order: %{total: total}}} <- products,
      reduce: Money.new(0)
    ) do
      cost ->
        [Money.new(0), total |> Money.parse!() |> Money.subtract(base_price)]
        |> Enum.max(Money)
        |> Money.add(cost)
    end
  end

  def placed?(%__MODULE__{placed_at: nil}), do: false
  def placed?(%__MODULE__{}), do: true

  def subtotal_cost(%__MODULE__{} = order) do
    order = Repo.preload(order, :digitals)

    for field <- [:products, :digitals], reduce: Money.new(0) do
      acc ->
        for(entry <- Map.get(order, field), reduce: acc) do
          acc ->
            Money.add(acc, entry.price)
        end
    end
  end

  def total_cost(order) do
    for f <- [&subtotal_cost/1, &shipping_cost/1], reduce: Money.new(0) do
      acc ->
        Money.add(acc, f.(order))
    end
  end
end
