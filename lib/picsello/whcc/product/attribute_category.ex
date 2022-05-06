defmodule Picsello.WHCC.Product.AttributeCategory do
  @moduledoc "find the cheapest set of selections for a product's attribute categories"

  @spec cheapest_selections(%{}, %{}) :: Picsello.WHCC.Product.SelectionSummary.t()
  def cheapest_selections(%{"attributes" => attributes} = category, valid_selections) do
    attributes
    |> Enum.flat_map(&selections(&1, category, valid_selections))
    |> Enum.min_by(&Map.get(&1, :price), fn -> %{selections: %{}, price: 0} end)
    |> then(&Map.update!(&1, :price, fn price -> Money.new(round(price * 100)) end))
  end

  defp selections(%{"pricing" => price, "id" => value}, %{"_id" => category}, _),
    do: [%{selections: %{category => value}, price: to_price(price)}]

  defp selections(
         %{"pricingRefs" => pricing_refs},
         %{"pricingRefsKey" => %{"keys" => keys, "separator" => separator}},
         valid_selections
       ) do
    for {category_ids, price} <- pricing_refs, reduce: [] do
      acc ->
        selections = Enum.zip(keys, String.split(category_ids, separator))

        metadata = Enum.map(selections, &get_in(valid_selections, Tuple.to_list(&1)))

        if Enum.all?(metadata) do
          [
            %{
              selections: Map.new(selections),
              price: to_price(price),
              metadata: Enum.reduce(metadata, &Map.merge/2)
            }
            | acc
          ]
        else
          acc
        end
    end
  end

  defp selections(_, _, _), do: []

  defp to_price(%{"base" => %{"value" => cents}}), do: cents
end
