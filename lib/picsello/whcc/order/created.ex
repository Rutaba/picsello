defmodule Picsello.WHCC.Order.Created do
  @moduledoc "Structure for WHCC order created"

  use StructAccess

  @derive Jason.Encoder
  defstruct [:entry, :confirmation, :total, :products]

  @type t :: %__MODULE__{
          entry: String.t(),
          confirmation: String.t(),
          total: String.t(),
          products: list()
        }

  def new(%{
        "ConfirmationID" => confirmation,
        "EntryID" => entry,
        "NumberOfOrders" => 1,
        "Orders" => [
          %{
            "Products" => products,
            "SubTotal" => sub_total
          }
        ]
      }) do
    %__MODULE__{
      confirmation: confirmation,
      entry: entry,
      total: sub_total,
      products: products
    }
  end

  defmodule Type do
    @moduledoc "Ecto type for created order"
    use Ecto.Type
    alias Picsello.WHCC.Order.Created

    def type, do: :map

    def cast(%Created{} = created_order), do: {:ok, created_order}
    def cast(data) when is_map(data), do: load(data)

    def cast(_), do: :error

    def load(data) when is_map(data) do
      data =
        for {key, val} <- data do
          {String.to_existing_atom(key), val}
        end

      {:ok, struct!(Created, data)}
    end

    def dump(%Created{} = created_order), do: {:ok, Map.from_struct(created_order)}
    def dump(_), do: :error
  end
end
