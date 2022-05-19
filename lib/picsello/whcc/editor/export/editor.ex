defmodule Picsello.WHCC.Editor.Export.Editor do
  @moduledoc """
  represents an item in the editors list of the export request body
  """

  defstruct [:id, order_attributes: [], quantity: 1]

  def new(id, opts \\ []) do
    %__MODULE__{
      id: id,
      order_attributes: Keyword.get(opts, :order_attributes, []),
      quantity: Keyword.get(opts, :quantity, 1)
    }
  end

  @type t :: %__MODULE__{id: String.t(), order_attributes: [integer()], quantity: integer()}
end

defimpl Jason.Encoder, for: Picsello.WHCC.Editor.Export.Editor do
  def encode(value, opts) do
    Jason.Encode.map(
      %{
        "editorId" => value.id,
        "orderAttributes" => value.order_attributes,
        "quantity" => value.quantity
      },
      opts
    )
  end
end
