defmodule Picsello.WHCC.Design do
  @moduledoc "a design from the whcc api"
  defstruct [:id, :name, :product_id, :attribute_categories, :api]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          product_id: String.t(),
          attribute_categories: [%{}],
          api: %{}
        }

  def from_map(%{"_id" => id, "name" => name, "product" => %{"_id" => product_id}} = design) do
    %__MODULE__{
      id: id,
      name: name,
      product_id: product_id,
      attribute_categories: [],
      api: Map.drop(design, ["product", "name", "_id"])
    }
  end

  def add_details(%__MODULE__{} = design, details) do
    %{
      design
      | attribute_categories: Map.get(details, "attributeCategories"),
        api: Map.drop(details, ["attributeCategories", "product", "name", "_id"])
    }
  end
end
