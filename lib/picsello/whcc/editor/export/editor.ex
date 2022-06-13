defmodule Picsello.WHCC.Editor.Export.Editor do
  @moduledoc """
  represents an item in the editors list of the export request body
  """

  defstruct [:id, :quantity, order_attributes: []]

  def new(id, opts \\ []) do
    %__MODULE__{
      id: id,
      order_attributes: Keyword.get(opts, :order_attributes, []),
      quantity: Keyword.get(opts, :quantity)
    }
  end

  @type t :: %__MODULE__{id: String.t(), order_attributes: [integer()], quantity: integer()}
end

defimpl Jason.Encoder, for: Picsello.WHCC.Editor.Export.Editor do
  def encode(%{quantity: nil} = value, opts), do: value |> to_map() |> Jason.Encode.map(opts)

  def encode(%{quantity: quantity} = value, opts),
    do: value |> to_map() |> Map.put("quantity", quantity) |> Jason.Encode.map(opts)

  defp to_map(value),
    do: %{
      "editorId" => value.id,
      "orderAttributes" => value.order_attributes
    }
end
