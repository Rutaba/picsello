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

  def from_map(%{"_id" => id}) do
    %__MODULE__{id: id}
  end

  def add_details(%__MODULE__{} = design, details) do
    %{
      design
      | attribute_categories: Map.get(details, "attributeCategories"),
        product_id: get_in(details, ["product", "_id"]),
        name: Map.get(details, "name"),
        api: Map.drop(details, ["attributeCategories", "product", "name"])
    }
  end
end
