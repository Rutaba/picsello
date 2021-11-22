defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback products() :: [Picsello.WHCC.Product.t()]
  @callback product_details(Picsello.WHCC.Product.t()) :: Picsello.WHCC.Product.t()

  def products(), do: impl().products()
  def product_details(product), do: impl().product_details(product)

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
