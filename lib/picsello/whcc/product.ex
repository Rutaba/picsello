defmodule Picsello.WHCC.Product do
  alias Picsello.WHCC.Category
  @moduledoc "a product from the whcc api"
  defstruct [:id, :name, :category]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          category: Category.t()
        }

  def from_map(%{"_id" => id, "category" => category, "name" => name}) do
    %__MODULE__{id: id, name: name, category: Category.from_map(category)}
  end
end
