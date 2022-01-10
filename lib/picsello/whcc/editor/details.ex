defmodule Picsello.WHCC.Editor.Details do
  @moduledoc "Editor detais structure to be used in cart"

  use StructAccess

  @derive Jason.Encoder
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

  defmodule Type do
    @moduledoc "Ecto type for editor details"
    use Ecto.Type
    alias Picsello.WHCC.Editor.Details

    def type, do: :map

    def cast(%Details{} = details), do: {:ok, details}
    def cast(data) when is_map(data), do: load(data)

    def cast(_), do: :error

    def load(data) when is_map(data) do
      data =
        for {key, val} <- data do
          {String.to_existing_atom(key), val}
        end

      {:ok, struct!(Details, data)}
    end

    def dump(%Details{} = details), do: {:ok, Map.from_struct(details)}
    def dump(_), do: :error
  end
end
