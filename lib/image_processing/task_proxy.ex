defmodule ImageProcessing.TaskProxy do
  @moduledoc """
  Finds all TaskKeepers and consumes them

  Rediscovers all TaskKeeper precesses in a cluster once per @timeout
  """

  use GenStage

  @initial_timeout 100
  @timeout 5000

  def start_link(_) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Process.send_after(self(), :discover_task_keepers, @initial_timeout)
    {:producer_consumer, []}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end

  def handle_info(:discover_task_keepers, state) do
    Process.send_after(self(), :discover_task_keepers, @timeout)
    {:noreply, [], discover_task_keepers(state)}
  end

  def discover_task_keepers(known_keepers) do
    nodes = [node() | Node.list()]

    new_keepers =
      nodes
      |> Enum.map(fn node -> :rpc.call(node, Process, :whereis, [ImageProcessing.TaskKeeper]) end)
      |> Enum.reject(fn pid -> is_nil(pid) or Enum.any?(known_keepers, &(&1 == pid)) end)

    new_keepers
    |> Enum.each(fn keeper -> GenStage.async_subscribe(self(), to: keeper) end)

    new_keepers ++ known_keepers
  end
end
