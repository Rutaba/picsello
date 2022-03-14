defmodule Picsello.WHCC.Product do
  alias Picsello.WHCC.{Category, Product.AttributeCategory}
  @moduledoc "a product from the whcc api"
  defstruct [:id, :name, :category, :attribute_categories, :api]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          category: Category.t(),
          attribute_categories: [%{}],
          api: %{}
        }

  def from_map(%{"_id" => id, "category" => category, "name" => name}) do
    %__MODULE__{id: id, name: name, category: Category.from_map(category)}
  end

  def add_details(%__MODULE__{} = product, api) do
    %{
      product
      | attribute_categories: Map.get(api, "attributeCategories"),
        api: Map.drop(api, ["attributeCategories"])
    }
  end

  def cheapest_selections(%{attribute_categories: attribute_categories} = _product) do
    valid_selections =
      for(
        %{"_id" => category_id, "attributes" => attributes} <- attribute_categories,
        into: %{},
        do:
          {category_id,
           for(
             %{"id" => id} = attribute <- attributes,
             into: %{},
             do: {id, Map.get(attribute, "metadata", %{})}
           )}
      )

    for %{"required" => true} = attribute_category <- attribute_categories,
        reduce: %{selections: %{}, price: Money.new(0), metadata: %{}} do
      acc ->
        attribute_category
        |> AttributeCategory.cheapest_selections(valid_selections)
        |> merge_selections(acc)
    end
  end

  defp merge_selections(a, b),
    do:
      Map.merge(a, b, fn
        :selections, a, b -> Map.merge(a, b)
        :metadata, a, b -> Map.merge(a, b)
        :price, a, b -> Money.add(a, b)
      end)
end
