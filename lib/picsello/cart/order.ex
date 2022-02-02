defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Cart.CartProduct
  alias Picsello.Cart.DeliveryInfo

  schema "gallery_orders" do
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :total_credits_amount, :integer, default: 0
    field :subtotal_cost, Money.Ecto.Amount.Type
    field :shipping_cost, Money.Ecto.Amount.Type, default: Money.new(0)
    field :placed, :boolean, default: false
    field :placed_at, :utc_datetime
    belongs_to(:gallery, Gallery)
    embeds_one :delivery_info, DeliveryInfo, on_replace: :delete
    embeds_many :products, CartProduct, on_replace: :delete

    embeds_many :digitals, Digital do
      field :photo_id, :integer
      field :preview_url, :string
      field :price, Money.Ecto.Amount.Type
    end

    timestamps(type: :utc_datetime)
  end

  def create_changeset(%CartProduct{price: price} = product, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:gallery_id])
    |> put_embed(:products, [product])
    |> cast_subtotal_cost({:default, price})
    |> validate_required([:gallery_id])
    |> foreign_key_constraint(:gallery_id)
  end

  def update_changeset(
        %__MODULE__{products: products} = order,
        %CartProduct{price: price} = product,
        attrs \\ %{}
      ) do
    product_already_exist =
      Enum.find_value(products, fn %{editor_details: %{editor_id: editor_id}} ->
        editor_id == product.editor_details.editor_id
      end)

    if product_already_exist do
      order
      |> change()
    else
      order
      |> cast(attrs, [])
      |> cast_subtotal_cost({:add, price})
      |> put_embed(:products, products ++ [product])
    end
  end

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
    |> cast_shipping_cost()
  end

  def confirmation_changeset(%__MODULE__{} = order, confirmed_products) do
    attrs = %{placed: true, placed_at: DateTime.utc_now()}

    order
    |> cast(attrs, [:placed, :placed_at])
    |> put_embed(:products, confirmed_products)
  end

  def store_delivery_info(order, delivery_info_changeset) do
    order
    |> change
    |> put_embed(:delivery_info, delivery_info_changeset)
  end

  defp replace_products(changeset, new_products) do
    new_product_ids = Enum.map(new_products, fn product -> product.editor_details.editor_id end)

    products_to_remain =
      changeset
      |> get_field(:products)
      |> Enum.filter(fn product -> product.editor_details.editor_id not in new_product_ids end)

    products_to_store =
      (products_to_remain ++ new_products)
      |> Enum.sort(&(&1.created_at < &2.created_at))

    changeset |> put_embed(:products, products_to_store)
  end

  def delete_product_changeset(%__MODULE__{products: products} = order, editor_id) do
    order
    |> change()
    |> put_embed(
      :products,
      Enum.filter(products, fn product -> product.editor_details.editor_id != editor_id end)
    )
  end

  defp cast_subtotal_cost(changeset, {:default, amount}),
    do: put_change(changeset, :subtotal_cost, amount)

  defp cast_subtotal_cost(changeset, {:add, amount}) do
    current_total_cost = get_field(changeset, :subtotal_cost)
    put_change(changeset, :subtotal_cost, Money.add(current_total_cost, amount))
  end

  defp cast_shipping_cost(changeset) do
    products = changeset |> get_field(:products)

    changeset
    |> put_change(
      :shipping_cost,
      Enum.reduce(products, Money.new(0), fn product, cost ->
        if product.whcc_order do
          product.whcc_order.total
        else
          "0"
        end
        |> Money.parse!()
        |> Money.subtract(product.base_price)
        |> Money.add(cost)
        |> reset_negative_cost()
      end)
    )
  end

  defp reset_negative_cost(cost) do
    if Money.negative?(cost) do
      Money.new(0)
    else
      cost
    end
  end
end
