defmodule Picsello.WHCC.Product do
  alias Picsello.WHCC.Category
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
end
