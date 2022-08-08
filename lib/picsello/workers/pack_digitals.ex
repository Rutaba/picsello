defmodule Picsello.Workers.PackDigitals do
  @moduledoc "Background job to create zip of digitals"

  use Oban.Worker, unique: [fields: [:args, :worker]]
  alias Picsello.{Repo, Orders, Orders.Pack}
  import Ecto.Query, only: [from: 2]

  def perform(%Oban.Job{args: args}) do
    {order_id, _args} = Map.pop(args, "order_id")

    case Pack.upload(order_id) do
      {:ok, path} -> Orders.broadcast(order_id, {:pack, :ok, %{order_id: order_id, path: path}})
      error -> Orders.broadcast(order_id, {:pack, :error, error})
    end
  end

  def executing?(%{id: order_id}) do
    worker = to_string(__MODULE__)

    from(job in Oban.Job,
      where:
        job.worker == ^worker and job.state == "executing" and
          fragment("(? -> 'order_id')::bigint = ?", job.args, ^order_id)
    )
    |> Repo.exists?()
  end
end
