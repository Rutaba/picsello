defmodule Picsello.WHCC.Editor.Export do
  @moduledoc """
  Editor export structure
  """

  defstruct [:items, :order, :pricing]

  defmodule Item do
    @moduledoc """
    a single exported editor
    """
    defstruct [:id, :unit_base_price, :editor, :quantity]

    def new(%{
          "id" => editor_id,
          "pricing" => %{"unitBasePrice" => unit_base_price, "quantity" => quantity},
          "editor" => editor
        }) do
      %__MODULE__{
        id: editor_id,
        unit_base_price: Money.new(round(unit_base_price * 100)),
        quantity: quantity,
        editor: editor
      }
    end

    @type t :: %__MODULE__{
            id: String.t(),
            unit_base_price: Money.t(),
            quantity: integer(),
            editor: map()
          }
  end

  @type t :: %__MODULE__{
          items: [Item.t()],
          order: map(),
          pricing: map()
        }

  def new(%{"items" => items, "order" => order, "pricing" => pricing}) do
    %__MODULE__{items: Enum.map(items, &Item.new/1), order: order, pricing: pricing}
  end
end
