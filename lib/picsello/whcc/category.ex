defmodule Picsello.WHCC.Category do
  @moduledoc "a category from the whcc api"
  defstruct [:id, :name]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }
end
