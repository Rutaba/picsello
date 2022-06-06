defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Cart.Product, Cart.DeliveryInfo, Cart.Digital, Galleries.Gallery}

  schema "gallery_orders" do
    field :bundle_price, Money.Ecto.Amount.Type
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :placed_at, :utc_datetime
    field :total_credits_amount, :integer, default: 0

    belongs_to(:gallery, Gallery)

    has_one :package, through: [:gallery, :package]
    has_one :invoice, Picsello.Invoices.Invoice
    has_one :intent, Picsello.Intents.Intent

    has_many :digitals, Digital,
      on_replace: :delete,
      on_delete: :delete_all,
      preload_order: [desc: :id]

    has_many :products, Product,
      on_replace: :delete,
      on_delete: :delete_all,
      preload_order: [desc: :id]

    embeds_one :delivery_info, DeliveryInfo, on_replace: :delete
    embeds_one :whcc_order, Picsello.WHCC.Order.Created, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  def create_changeset(product, attrs \\ %{}, opts \\ [])

  def create_changeset(%Product{} = product, attrs, opts) do
    attrs
    |> do_create_changeset()
    |> put_assoc(:products, [
      Product.update_price(product, Keyword.put(opts, :shipping_base_charge, true))
    ])
  end

  def create_changeset(%Digital{} = digital, attrs, opts) do
    attrs
    |> do_create_changeset()
    |> put_assoc(:digitals, [%{digital | is_credit: is_credit(opts)}])
  end

  def create_changeset({:bundle, price}, attrs, _opts) do
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

  def update_changeset(order, product, attrs \\ %{}, opts \\ [])

  def update_changeset(order, {:bundle, price}, attrs, _opts) do
    order
    |> cast(attrs, [])
    |> put_change(:bundle_price, price)
    |> put_assoc(:digitals, [])
  end

  def update_changeset(%{products: products} = cart, %Product{} = product, attrs, opts)
      when is_list(products) do
    cart
    |> cast(Map.put(attrs, :products, update_prices([product | products], opts)), [])
    |> cast_assoc(:products)
  end

  def update_changeset(%__MODULE__{digitals: digitals} = order, %Digital{} = digital, attrs, opts)
      when is_list(digitals) do
    order
    |> cast(attrs, [])
    |> put_assoc(:digitals, [%{digital | is_credit: is_credit(opts)} | digitals])
  end

  def whcc_order_changeset(%{products: products} = order, params) when is_list(products) do
    order
    |> cast(%{whcc_order: params}, [])
    |> cast_embed(:whcc_order)
  end

  def placed_changeset(order),
    do: change(order, %{placed_at: DateTime.utc_now() |> DateTime.truncate(:second)})

  def whcc_confirmation_changeset(%__MODULE__{} = order) do
    order
    |> cast(%{whcc_order: %{confirmed_at: DateTime.utc_now()}}, [])
    |> cast_embed(:whcc_order)
  end

  def store_delivery_info(order, delivery_info_changeset) do
    order
    |> change
    |> put_embed(:delivery_info, delivery_info_changeset)
  end

  def number(%__MODULE__{id: id}), do: Picsello.Cart.OrderNumber.to_number(id)
  def number(id), do: Picsello.Cart.OrderNumber.to_number(id)

  def delete_product_changeset(%__MODULE__{} = order, opts) do
    case {opts, order} do
      {:bundle, _} ->
        order
        |> change()
        |> put_change(:bundle_price, nil)

      {[editor_id: editor_id], %{products: products}} when is_list(products) ->
        order
        |> change()
        |> put_assoc(
          :products,
          products |> Enum.reject(&(&1.editor_id == editor_id)) |> update_prices(opts)
        )

      {[digital_id: digital_id], %{digitals: digitals}} when is_list(digitals) ->
        order_credit_count = Enum.count(digitals, & &1.is_credit)

        {_, digitals} =
          digitals
          |> Enum.reduce({0, []}, fn
            %{id: ^digital_id}, acc ->
              acc

            digital, {index, acc} ->
              {index + 1, [%{digital | is_credit: index < order_credit_count} | acc]}
          end)

        order |> change() |> put_assoc(:digitals, digitals)
    end
  end

  def placed?(%__MODULE__{placed_at: nil}), do: false
  def placed?(%__MODULE__{}), do: true

  def product_total(%__MODULE__{products: products}) when is_list(products) do
    for product <- products, reduce: Money.new(0) do
      sum -> product |> Product.charged_price() |> Money.add(sum)
    end
  end

  def digital_total(%__MODULE__{digitals: digitals, bundle_price: bundle_price})
      when is_list(digitals) do
    for digital <- digitals, reduce: bundle_price || Money.new(0) do
      sum -> digital |> Digital.charged_price() |> Money.add(sum)
    end
  end

  def total_cost(%__MODULE__{} = order) do
    Money.add(digital_total(order), product_total(order))
  end

  defp update_prices(products, opts) do
    for {_, line_items} <- sort_products(products), reduce: [] do
      products ->
        for {product, index} <- Enum.with_index(line_items), reduce: products do
          products ->
            [
              Product.update_price(product, Keyword.put(opts, :shipping_base_charge, index == 0))
              | products
            ]
        end
    end
    |> Enum.reverse()
  end

  def lines_by_product(%__MODULE__{products: products}), do: products |> sort_products()

  defp sort_products(products) do
    products
    |> Enum.sort_by(& &1.id)
    |> Enum.reverse()
    |> Enum.group_by(fn %{whcc_product: %Picsello.Product{} = whcc_product} ->
      Map.take(whcc_product, [:id, :whcc_name])
    end)
    |> Enum.sort_by(fn {_whcc_product, cart_products} ->
      cart_products |> Enum.map(& &1.id) |> Enum.max()
    end)
    |> Enum.reverse()
  end

  defp is_credit(opts) do
    (get_in(opts, [:credits, :digital]) || 0) > 0
  end
end
