defmodule Picsello.Workers.Checkout do
  @moduledoc "Background job to check out an order"
  use Oban.Worker, queue: :default
  alias Picsello.{Repo, Cart.Order, Intents}

  import Ecto.Query, only: [from: 2]

  import Picsello.Cart, only: [preload_digitals: 1]

  import Picsello.Cart.Checkouts, only: [create_session: 2, create_whcc_order: 1]

  require Logger

  def perform(%Oban.Job{args: args}) do
    {order_id, opts} = Map.pop(args, "order_id")

    order =
      from(order in Order,
        preload: [gallery: :organization, products: :whcc_product],
        where: order.id == ^order_id
      )
      |> preload_digitals()
      |> Repo.one!()

    message =
      if order |> Order.total_cost() |> Money.zero?() do
        {:checkout, :complete, order}
      else
        with {:ok, %{payment_intent: payment_intent, url: url}} <-
               create_session(order, Map.put(opts, :expand, [:payment_intent])),
             {:ok, _intent} <- Intents.create(payment_intent, order) do
          {:checkout, :due, url}
        else
          error ->
            Logger.error("cannot check out order #{order.id}.\n#{inspect(error)}")
            {:checkout, :error, "something wen't wrong"}
        end
      end

    order |> Order.placed_changeset() |> Repo.update!()
    broadcast(order, message)

    if order.products != [] do
      order = create_whcc_order(order)

      broadcast(order, {:checkout, :whcc_order_created, order})
    end

    :ok
  end

  defdelegate broadcast(order, message), to: Picsello.Orders
end
