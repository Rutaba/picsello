defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback products() :: [Picsello.WHCC.Product.t()]
  @callback product_details(Picsello.WHCC.Product.t()) :: Picsello.WHCC.Product.t()
  @callback designs() :: [Picsello.WHCC.Design.t()]
  @callback design_details(Picsello.WHCC.Design.t()) :: Picsello.WHCC.Design.t()
  @callback editor(map()) :: Picsello.WHCC.CreatedEditor.t()
  @callback editor_details(String.t()) :: map()

  def products(), do: impl().products()
  def product_details(product), do: impl().product_details(product)

  def designs(), do: impl().designs()
  def design_details(design), do: impl().design_details(design)

  def editor(data), do: impl().editor(data)
  def editor_details(id), do: impl().editor_details(id)

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
