defmodule Picsello.WHCC.Order.Created do
  @moduledoc "Structure for WHCC order created"

  defmodule Order do
    @moduledoc "stores one item from the orders list in the created response"

    use Ecto.Schema
    @primary_key false
    embedded_schema do
      field :total, Money.Ecto.Type
      field :api, :map
    end

    @type t :: %__MODULE__{
            api: map(),
            total: Money.t()
          }

    def new(%{"Total" => total} = order) do
      total =
        total
        |> Decimal.new()
        |> Decimal.mult(100)
        |> Decimal.round()
        |> Decimal.to_integer()
        |> Money.new()

      %__MODULE__{total: total, api: Map.drop(order, ["Total"])}
    end
  end

  use StructAccess
  use Ecto.Schema
  @primary_key false
  embedded_schema do
    field :entry, :string
    field :confirmation, :string
    embeds_many :orders, Order
  end

  @type t :: %__MODULE__{
          entry: String.t(),
          confirmation: String.t(),
          orders: [Order.t()]
        }

  def new(%{
        "ConfirmationID" => confirmation,
        "EntryID" => entry,
        "Orders" => orders
      }),
      do: %__MODULE__{
        confirmation: confirmation,
        entry: entry,
        orders: Enum.map(orders, &Order.new/1)
      }

  def total(%__MODULE__{orders: orders}),
    do:
      (for %{total: total} <- orders, reduce: Money.new(0) do
         sum -> Money.add(sum, total)
       end)
end
