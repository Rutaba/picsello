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
    embeds_one :delivery_info, DeliveryInfo
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
    order
    |> cast(attrs, [])
    |> cast_subtotal_cost({:add, price})
    |> put_embed(:products, products ++ [product])
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
    |> cast_shipping_cost(products)
    |> put_embed(:products, products)
  end

  def confirmation_changeset(%__MODULE__{} = order, confirmed_products) do
    attrs = %{placed: true, placed_at: DateTime.utc_now()}

    order
    |> cast(attrs, [:placed, :placed_at])
    |> put_embed(:products, confirmed_products)
  end

  defp cast_subtotal_cost(changeset, {:default, amount}),
    do: put_change(changeset, :subtotal_cost, amount)

  defp cast_subtotal_cost(changeset, {:add, amount}) do
    current_total_cost = get_field(changeset, :subtotal_cost)
    put_change(changeset, :subtotal_cost, Money.add(current_total_cost, amount))
  end

  defp cast_shipping_cost(changeset, products) do
    changeset
    |> put_change(
      :shipping_cost,
      Enum.reduce(products, Money.new(0), fn product, cost ->
        product.whcc_order.total
        |> Money.parse!()
        |> Money.subtract(product.base_price)
        |> Money.add(cost)
      end)
    )
  end
end
