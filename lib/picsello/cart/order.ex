defmodule Picsello.Cart.Order do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Cart.CartProduct

  schema "gallery_orders" do
    field :number, :integer, default: Enum.random(100_000..999_999)
    field :total_credits_amount, :integer, default: 0
    field :subtotal_cost, Money.Ecto.Amount.Type
    field :shipping_cost, Money.Ecto.Amount.Type, default: Money.new(0)
    field :placed, :boolean, default: false
    belongs_to(:gallery, Gallery)
    embeds_many :products, CartProduct, on_replace: :delete

    embeds_many :digitals, Digital do
      field :photo_id, :integer
      field :preview_url, :string
      field :price, Money.Ecto.Amount.Type
    end

    embeds_one :delivery_info, DeliveryInfo do
      field :type, :string
      field :name, :string
      field :city, :string
      field :state, :string
      field :zip, :integer
      field :address_line1, :string
      field :address_line2, :string
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

  defp cast_subtotal_cost(changeset, {:default, amount}),
    do: put_change(changeset, :subtotal_cost, amount)

  defp cast_subtotal_cost(changeset, {:add, amount}) do
    current_total_cost = get_field(changeset, :subtotal_cost)
    put_change(changeset, :subtotal_cost, Money.add(current_total_cost, amount))
  end
end
