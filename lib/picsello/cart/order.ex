defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Cart.Product, Cart.DeliveryInfo, Cart.Digital, Galleries.Gallery, Repo}

  schema "gallery_orders" do
    field :bundle_price, Money.Ecto.Amount.Type
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :placed_at, :utc_datetime
    field :total_credits_amount, :integer, default: 0

    belongs_to(:gallery, Gallery)

    has_one :package, through: [:gallery, :package]

    has_many :digitals, Digital, on_replace: :delete, on_delete: :delete_all
    has_many :products, Product, on_replace: :delete, on_delete: :delete_all

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

  def create_changeset(%Digital{} = digital, attrs, _opts) do
    attrs
    |> do_create_changeset()
    |> put_assoc(:digitals, [%{digital | position: 0}])
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
    |> cast(attrs, [])
    |> put_assoc(:products, update_prices([product | products], opts))
  end

  def update_changeset(%__MODULE__{} = order, %Digital{} = digital, attrs, _opts) do
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

  def update_changeset(changeset, %Digital{} = digital, attrs, _opts),
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

  def whcc_order_changeset(%{products: products} = order, params) when is_list(products) do
    order
    |> cast(%{whcc_order: params}, [])
    |> cast_embed(:whcc_order)
  end

  def confirmation_changeset(
        %__MODULE__{} = order,
        _confirmation \\ nil
      ) do
    attrs = %{placed_at: DateTime.utc_now()}

    order
    |> cast(attrs, [:placed_at])
  end

  def store_delivery_info(order, delivery_info_changeset) do
    order
    |> change
    |> put_embed(:delivery_info, delivery_info_changeset)
  end

  def number(%__MODULE__{id: id}), do: Picsello.Cart.OrderNumber.to_number(id)

  def delete_product_changeset(%__MODULE__{products: products} = order, opts) do
    case opts do
      :bundle ->
        order
        |> change()
        |> put_change(:bundle_price, nil)

      [editor_id: editor_id] ->
        order
        |> change()
        |> put_assoc(
          :products,
          products |> Enum.reject(&(&1.editor_id == editor_id)) |> update_prices(opts)
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
       for %{price: price, volume_discount: volume_discount} = product_line <- product_lines do
         %{
           line_item: product_line,
           price: Money.subtract(price, volume_discount),
           price_without_discount: price
         }
       end}
    end
  end

  # no longer needed?
  def priced_lines(order),
    do: order |> priced_lines_by_product() |> Enum.map(&elem(&1, 1)) |> List.flatten()

  def product_total(%__MODULE__{products: products} = order) when is_list(products) do
    for %{price: price} <- priced_lines(order), reduce: Money.new(0) do
      sum -> Money.add(sum, price)
    end
  end

  def digital_total(%__MODULE__{digitals: digitals, bundle_price: bundle_price})
      when is_list(digitals) do
    for %{price: price} <- digitals, reduce: bundle_price || Money.new(0) do
      sum -> Money.add(sum, price)
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
  end

  defp line_items_by_product(%__MODULE__{products: products}) do
    products |> sort_products()
  end

  defp sort_products(products) do
    products
    |> Enum.map(& &1.inserted_at)
    |> Enum.reduce(
      [],
      fn %{whcc_product: %Picsello.Product{id: whcc_product_id} = product} = line, acc ->
        {added, grouped} =
          Enum.reduce(acc, {false, []}, fn
            {%{id: ^whcc_product_id} = p, lines}, {_added, grouped} ->
              {true, [{p, [line | lines]} | grouped]}

            entry, {added, grouped} ->
              {added, [entry | grouped]}
          end)

        if added, do: grouped, else: [{product, [line]} | grouped]
      end
    )
    |> Enum.sort_by(fn {_product, line_items} ->
      line_items |> Enum.map(& &1.inserted_at) |> Enum.max()
    end)
    |> Enum.reverse()
  end
end
