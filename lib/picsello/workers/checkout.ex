defmodule Picsello.Workers.Checkout do
  @moduledoc "Background job to check out an order"
  use Oban.Worker, queue: :default, unique: [period: :infinity]
  alias Picsello.{Orders, Cart.Checkouts}

  require Logger

  def perform(%Oban.Job{args: args}) do
    {order_id, opts} = Map.pop(args, "order_id")

    case Checkouts.check_out(order_id, opts) do
      {:ok, %{order: order, session: %{url: url}}} ->
        Orders.broadcast(order, {:checkout, :due, url})

      {:ok, %{order: order}} ->
        Orders.broadcast(order, {:checkout, :complete, order})

      err ->
        Logger.error("[Checkout] unexpected response:\n#{inspect(err)}")
        Orders.broadcast(order_id, {:checkout, :error, err})
    end
  end
end
