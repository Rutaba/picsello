defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback products() :: [Picsello.WHCC.Product.t()]

  def products(), do: impl().products()

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
