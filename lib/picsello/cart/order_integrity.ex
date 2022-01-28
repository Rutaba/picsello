defmodule Picsello.Cart.OrderIntegrity do
  @moduledoc "Service module to updfate DB order structures"

  alias Picsello.Repo
  alias Picsello.Cart.Order

  def update_order_numbers() do
    Order
    |> Repo.all()
    |> Enum.each(&Picsello.Cart.set_order_number/1)
  end
end
