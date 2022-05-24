defmodule Picsello.WHCC.Editor.Export do
  @moduledoc """
  Editor export structure
  """

  defstruct [:items, :order, :pricing]

  defmodule Item do
    @moduledoc """
    a single exported editor
    """
    defstruct [:id, :unit_base_price, :editor, :quantity, :order_sequence_number]

    def new(
          %{
            "id" => editor_id,
            "pricing" => %{"unitBasePrice" => unit_base_price, "quantity" => quantity},
            "editor" => editor
          },
          sequence_number: sequence_number
        ) do
      %__MODULE__{
        id: editor_id,
        unit_base_price: Money.new(round(unit_base_price * 100)),
        quantity: quantity,
        order_sequence_number: sequence_number,
        editor: editor
      }
    end

    @type t :: %__MODULE__{
            id: String.t(),
            unit_base_price: Money.t(),
            quantity: integer(),
            editor: map(),
            order_sequence_number: integer()
          }
  end

  @type t :: %__MODULE__{
          items: [Item.t()],
          order: map(),
          pricing: map()
        }

  def new(%{"items" => items, "order" => %{"Orders" => sub_orders} = order, "pricing" => pricing}) do
    %__MODULE__{
      items:
        for %{"id" => item_id} = item <- items,
            %{"SequenceNumber" => sequence_number, "OrderItems" => order_items} <- sub_orders,
            %{"EditorId" => ^item_id} <- order_items do
          Item.new(item, sequence_number: sequence_number)
        end,
      order: order,
      pricing: pricing
    }
  end
end
