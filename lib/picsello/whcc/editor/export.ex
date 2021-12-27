defmodule Picsello.WHCC.Editor.Export do
  @moduledoc """
  Editor export structure
  """

  defstruct [:items, :order, :pricing]

  @type t :: %__MODULE__{
          items: list(),
          order: map(),
          pricing: map()
        }

  def new(%{"items" => items, "order" => order, "pricing" => pricing}) do
    %__MODULE__{
      items: items,
      order: order,
      pricing: pricing
    }
  end
end
