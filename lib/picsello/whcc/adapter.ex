defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback categories() :: [Picsello.WHCC.Category.t()]

  def categories(), do: impl().categories()

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
