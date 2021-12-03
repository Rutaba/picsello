defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback products() :: [Picsello.WHCC.Product.t()]
  @callback product_details(Picsello.WHCC.Product.t()) :: Picsello.WHCC.Product.t()
  @callback designs() :: [Picsello.WHCC.Design.t()]
  @callback design_details(Picsello.WHCC.Design.t()) :: Picsello.WHCC.Design.t()

  def products(), do: impl().products()
  def product_details(product), do: impl().product_details(product)

  def designs(), do: impl().designs()
  def design_details(design), do: impl().design_details(design)

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
