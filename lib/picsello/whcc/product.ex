defmodule Picsello.WHCC.Product do
  alias Picsello.WHCC.{Category, Product.AttributeCategory}
  @moduledoc "a product from the whcc api"
  defstruct [:id, :name, :category, :attribute_categories, :api]

  import Money.Sigils

  defmodule SelectionSummary do
    @moduledoc """
      a set of WHCC editor selections, the resulting price and the related metadata
    """

    defstruct selections: %{}, metadata: %{}, price: ~M[0]USD

    @type t :: %__MODULE__{
            selections: %{},
            metadata: %{},
            price: %Money{}
          }

    @spec merge(t(), t()) :: t()
    def merge(a, b),
      do:
        Map.merge(a, b, fn
          :selections, a, b -> Map.merge(a, b)
          :metadata, a, b -> Map.merge(a, b)
          :price, a, b -> Money.add(a, b)
        end)
  end

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

  @spec cheapest_selections(%{attribute_categories: [%{}]}) :: SelectionSummary.t()
  def cheapest_selections(product), do: selections(product, :min)

  @spec highest_selections(%{attribute_categories: [%{}]}) :: SelectionSummary.t()
  def highest_selections(product), do: selections(product, :max)

  @types ~w(min max)a
  def selections(%{attribute_categories: attribute_categories}, type) when type in @types do
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
        |> AttributeCategory.require_selections(valid_selections, type)
        |> SelectionSummary.merge(acc)
    end
  end

  def selection_unit_price(%{attribute_categories: attribute_categories}, selections) do
    for {category_id, _value} <- selections,
        %{"_id" => ^category_id} = category <- attribute_categories,
        reduce: ~M[0] do
      total ->
        Money.add(total, AttributeCategory.price(category, selections))
    end
  end

  def selection_details(
        %{attribute_categories: attribute_categories} = _product,
        %{} = selections
      ) do
    map =
      for(
        %{"_id" => category_id, "attributes" => attributes} <- attribute_categories,
        into: %{}
      ) do
        {category_id,
         for(%{"id" => attribute_id} = attribute <- attributes, into: %{}) do
           {attribute_id, attribute}
         end}
      end

    for({category_id, attribute_id} <- selections, into: %{}) do
      {category_id, get_in(map, [category_id, attribute_id])}
    end
  end

  def selection_details(product, %{} = selections, %{id: category_id}) do
    if category_id == get_card_category_id() do
      %{"size" => %{"metadata" => get_in(product, [:api, "metadata"])}}
    else
      map =
        for(
          %{"_id" => category_id, "attributes" => attributes} <- product.attribute_categories,
          into: %{}
        ) do
          {category_id,
           for(%{"id" => attribute_id} = attribute <- attributes, into: %{}) do
             {attribute_id, attribute}
           end}
        end

      for({category_id, attribute_id} <- selections, into: %{}) do
        {category_id, get_in(map, [category_id, attribute_id])}
      end
    end
  end

  defp get_card_category_id(), do: Application.get_env(:picsello, :card_category_id)
end
