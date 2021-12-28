defmodule Picsello.WHCC.Order.Params do
  @moduledoc "Structure to create WHCC order"
  alias Picsello.WHCC.Editor.Export

  def from_export(
        %Export{items: [%{"id" => editor_id} | _]} = export,
        opts
      ) do
    %{} = ship_to = Keyword.get(opts, :ship_to)
    %{} = return_to = Keyword.get(opts, :return_to)
    [_] = attributes = Keyword.get(opts, :attributtes)

    export.order
    |> Map.put("EntryId", editor_id)
    |> then(fn x ->
      Map.put(
        x,
        "Orders",
        x["Orders"]
        |> Enum.map(fn order ->
          order
          |> Map.merge(%{
            "OrderAttributes" => attributes,
            "ShipToAddress" => ship_to,
            "ShipFromAddress" => return_to
          })
        end)
      )
    end)
  end
end
