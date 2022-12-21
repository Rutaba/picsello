defmodule Picsello.WHCC.Product.AttributeCategory do
  @moduledoc "find the cheapest set of selections for a product's attribute categories"

  import Money.Sigils

  def require_selections(attribute_category, valid_selections, :min) do
    attribute_category
    |> selections(valid_selections)
    |> Enum.min_by(&Map.get(&1, :price), fn -> %{selections: %{}, price: ~M[0]USD} end)
  end

  def require_selections(attribute_category, valid_selections, :max) do
    attribute_category
    |> selections(valid_selections)
    |> Enum.max_by(&Map.get(&1, :price), fn -> %{selections: %{}, price: ~M[0]USD} end)
  end
  def price(
        %{"attributes" => attributes, "_id" => category_id} = category,
        selections
      ) do
    attributes
    |> Enum.find(&(Map.get(&1, "id") == Map.get(selections, category_id)))
    |> attribute_price(category, selections)
  end

  defp attribute_price(
         %{"pricingRefs" => pricing_refs},
         %{"pricingRefsKey" => %{"keys" => keys, "separator" => separator}},
         selections
       ) do
    key = keys |> Enum.map(&Map.get(selections, &1)) |> Enum.join(separator)

    case Map.get(pricing_refs, key) do
      nil -> ~M[0]USD
      value -> to_price(value)
    end
  end

  defp attribute_price(%{"pricing" => pricing}, _, _), do: to_price(pricing)
  defp attribute_price(_, _, _), do: ~M[0]USD

  def selections(%{"attributes" => attributes} = category, valid_selections),
    do: Enum.flat_map(attributes, &selections(&1, category, valid_selections))

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

  defp to_price(%{"base" => %{"value" => dollars}}), do: Money.new(floor(dollars * 100), :USD)
end
