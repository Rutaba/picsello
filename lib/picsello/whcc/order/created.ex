defmodule Picsello.WHCC.Order.Created do
  @moduledoc "Structure for WHCC order created"
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
end
