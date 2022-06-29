defmodule Picsello.Workers.Checkout do
  @moduledoc "Background job to check out an order"
  use Oban.Worker,
    queue: :default,
    unique: [states: ~w[available scheduled executing retryable]a, period: :infinity]

  alias Picsello.{Orders, Cart.Checkouts}

  require Logger

  def perform(%Oban.Job{args: args}) do
    {order_id, opts} = Map.pop(args, "order_id")
    {helpers_module, opts} = Map.pop(opts, "helpers")

    case Checkouts.check_out(order_id, opts) do
      {:ok, %{cart: cart, session: %{url: url}}} ->
        Orders.broadcast(cart, {:checkout, :due, url})

      {:ok, %{order: order}} ->
        Orders.broadcast(order, {:checkout, :complete, order})

        Picsello.Notifiers.OrderNotifier.deliver_order_confirmation_emails(
          order,
          String.to_existing_atom(helpers_module)
        )

      err ->
        Logger.error("[Checkout] unexpected response:\n#{inspect(err)}")
        Orders.broadcast(order_id, {:checkout, :error, err})
    end
  end
end
