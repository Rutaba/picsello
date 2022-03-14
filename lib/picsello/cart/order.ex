defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Cart.{CartProduct, DeliveryInfo}

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

    embeds_many :digitals, Digital, on_replace: :delete do
      field :photo_id, :integer
      field :preview_url, :string
      field :price, Money.Ecto.Amount.Type
    end

    timestamps(type: :utc_datetime)
  end

  alias __MODULE__.Digital

  def create_changeset(product, attrs \\ %{})

  def create_changeset(%CartProduct{} = product, attrs) do
    attrs
    |> do_create_changeset()
    |> put_embed(:products, [product])
    |> refresh_costs()
  end

  def create_changeset(%Digital{} = digital, attrs) do
    attrs
    |> do_create_changeset()
    |> put_embed(:digitals, [digital])
    |> refresh_costs()
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

  def update_changeset(order, %Digital{} = digital, attrs) do
    order
    |> cast(attrs, [])
    |> then(fn changeset ->
      digitals = get_field(changeset, :digitals, [])

      if Enum.any?(digitals, &(&1.photo_id == digital.photo_id)) do
        changeset
      else
        put_embed(changeset, :digitals, [digital | digitals])
      end
    end)
    |> refresh_costs()
  end

  def change_products(
        %__MODULE__{} = order,
        products,
        attrs \\ %{}
      ) do
    order
    |> cast(attrs, [])
    |> put_embed(:products, products)
    |> refresh_costs()
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
    |> refresh_costs()
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

    changeset
    |> put_embed(:products, products_to_store)
    |> refresh_costs()
  end

  def delete_product_changeset(%__MODULE__{products: products, digitals: digitals} = order, opts) do
    {embed, values} =
      case opts do
        [editor_id: editor_id] ->
          {:products, Enum.reject(products, &(&1.editor_details.editor_id == editor_id))}

        [digital_id: digital_id] ->
          {:digitals, Enum.reject(digitals, &(&1.id == digital_id))}
      end

    order
    |> change()
    |> put_embed(embed, values)
    |> refresh_costs()
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

  defp refresh_costs(changeset) do
    costs =
      for field <- [:products, :digitals], reduce: Money.new(0) do
        acc ->
          for(entry <- get_field(changeset, field), reduce: acc) do
            acc ->
              Money.add(acc, entry.price)
          end
      end

    put_change(changeset, :subtotal_cost, costs)
  end
end
