defmodule Picsello.WHCC.Adapter do
  @moduledoc false
  @callback products() :: [Picsello.WHCC.Product.t()]
  @callback product_details(Picsello.WHCC.Product.t()) :: Picsello.WHCC.Product.t()
  @callback designs() :: [Picsello.WHCC.Design.t()]
  @callback design_details(Picsello.WHCC.Design.t()) :: Picsello.WHCC.Design.t()
  @callback editor(map()) :: Picsello.WHCC.CreatedEditor.t()
  @callback editor_details(String.t(), String.t()) :: Picsello.WHCC.Editor.Details.t()
  @callback editor_export(String.t(), String.t()) :: Picsello.WHCC.Editor.Export.t()
  @callback create_order(String.t(), String.t(), Keyword.t()) :: Picsello.WHCC.Order.Created.t()
  @callback confirm_order(String.t(), String.t()) :: atom() | {:error, any()}

  def products(), do: impl().products()
  def product_details(product), do: impl().product_details(product)

  def designs(), do: impl().designs()
  def design_details(design), do: impl().design_details(design)

  def editor(data), do: impl().editor(data)
  def editor_details(account_id, id), do: impl().editor_details(account_id, id)
  def editor_export(account_id, id), do: impl().editor_export(account_id, id)

  def create_order(account_id, id, opts), do: impl().create_order(account_id, id, opts)

  def confirm_order(account_id, confirmation),
    do: impl().confirm_order(account_id, confirmation)

  defp impl, do: Application.get_env(:picsello, :whcc) |> Keyword.get(:adapter)
end
