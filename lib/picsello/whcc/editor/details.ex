defmodule Picsello.WHCC.Editor.Details do
  @moduledoc "Editor detais structure to be used in cart"
  defstruct [:product_id, :editor_id, :preview_url, :selections]

  @type t :: %__MODULE__{
          editor_id: String.t(),
          product_id: String.t(),
          preview_url: String.t(),
          selections: %{}
        }

  def new(%{
        "_id" => editor_id,
        "productId" => product_id,
        "selections" => selections,
        "productPreviews" => preview
      }) do
    url =
      preview
      |> Map.to_list()
      |> then(fn [{_, x} | _] -> x end)
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

  defimpl Jason.Encoder, for: Picsello.WHCC.Editor.Details do
    def encode(value, opts) do
      Jason.Encode.map(
        Map.take(value, [:editor_id, :preview_url, :product_id, :selections]),
        opts
      )
    end
  end
end
