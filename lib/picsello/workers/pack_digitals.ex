defmodule Picsello.Workers.PackDigitals do
  @moduledoc "Background job to create zip of digitals"

  use Oban.Worker, unique: [fields: [:args, :worker]]
  alias Picsello.{Galleries, Galleries.Gallery, Orders, Cart.Order, Pack}

  def perform(%Oban.Job{args: %{"packable" => module_name, "id" => id}}) do
    packable = module_name |> String.to_existing_atom() |> struct(id: id)

    case Pack.upload(packable) do
      {:ok, path} ->
        broadcast(packable, :ok, %{packable: packable, path: path})
        :ok

      error ->
        broadcast(packable, :error, %{error: error})
        {:error, error}
    end
  end

  def enqueue(%{id: id, __struct__: packable}) do
    %{id: id, packable: packable}
    |> __MODULE__.new()
    |> Oban.insert()
  end

  defp broadcast(packable, status, payload) do
    context_module(packable).broadcast(
      packable,
      {:pack, status, Map.put(payload, :packable, packable)}
    )
  end

  defp context_module(%Order{}), do: Orders
  defp context_module(%Gallery{}), do: Galleries
end
