defmodule Picsello.WHCC.Editor.Details do
  defstruct [:product_id, :editor_id, :preview_url, :selections]

  def new(%{
        "_id" => editor_id,
        "productId" => product_id,
        "selections" => selections,
        "productPreviews" => preview
      }) do
    url =
      preview
      |> Map.to_list()
      |> Enum.at(0)
      |> then(fn {_, x} -> x end)
      |> Map.get("scale_1024")

    %__MODULE__{
      editor_id: editor_id,
      product_id: product_id,
      preview_url: url,
      selections:
        selections
        |> Map.drop(["photo"])
    }
  end
end
