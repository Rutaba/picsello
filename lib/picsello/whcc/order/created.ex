defmodule Picsello.WHCC.Order.Created do
  @moduledoc "Structure for WHCC order created"

  defmodule Order do
    @moduledoc "stores one item from the orders list in the created response"

    use Ecto.Schema
    import Ecto.Changeset
    @primary_key {:sequence_number, :integer, autogenerate: false}
    embedded_schema do
      field :total, Money.Ecto.Type
      field :editor_ids, {:array, :string}
      field :api, :map
      embeds_one :whcc_processing, Picsello.WHCC.Webhooks.Status
      embeds_one :whcc_tracking, Picsello.WHCC.Webhooks.Event
    end

    @type t :: %__MODULE__{
            api: map(),
            sequence_number: integer(),
            total: Money.t(),
            editor_ids: nil | list()
          }

    def new(%{"Total" => total, "SequenceNumber" => sequence_number} = order) do
      total =
        total
        |> Decimal.new()
        |> Decimal.mult(100)
        |> Decimal.round()
        |> Decimal.to_integer()
        |> Money.new()

      %__MODULE__{
        total: total,
        sequence_number: String.to_integer(sequence_number),
        api: Map.drop(order, ["Total", "SequenceNumber"])
      }
    end

    def changeset(order, %Picsello.WHCC.Webhooks.Event{} = status) do
      order |> change() |> put_embed(:whcc_tracking, status)
    end

    def changeset(order, %Picsello.WHCC.Webhooks.Status{} = status) do
      order |> change() |> put_embed(:whcc_processing, status)
    end

    def changeset(order, params) do
      order
      |> cast(params |> Map.from_struct(), ~w[total editor_ids api sequence_number]a)
    end
  end

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:entry_id, :string, autogenerate: false}
  embedded_schema do
    field :confirmation_id, :string
    field :confirmed_at, :utc_datetime
    embeds_many :orders, Order, on_replace: :delete
  end

  @type t :: %__MODULE__{
          entry_id: String.t(),
          confirmation_id: String.t(),
          orders: [Order.t()]
        }

  def new(%{"ConfirmationID" => confirmation_id, "EntryID" => entry_id, "Orders" => orders}) do
    %__MODULE__{
      confirmation_id: confirmation_id,
      entry_id: entry_id,
      orders: Enum.map(orders, &Order.new/1)
    }
  end

  def changeset(
        %{orders: orders} = created,
        %{sequence_number: status_sequence_number} = status
      ) do
    created
    |> cast(
      %{
        orders:
          for(
            order <- orders,
            do: if(order.sequence_number == status_sequence_number, do: status, else: order)
          )
      },
      []
    )
    |> cast_embed(:orders)
  end

  def changeset(created, payload) when is_struct(payload) do
    created
    |> cast(Map.from_struct(payload), [:entry_id, :confirmation_id])
    |> cast_embed(:orders)
  end

  def changeset(created, attrs) do
    cast(created, attrs, [:confirmed_at])
  end

  def total(%__MODULE__{orders: orders}),
    do:
      (for %{total: total} <- orders, reduce: Money.new(0) do
         sum -> Money.add(sum, total)
       end)
end
