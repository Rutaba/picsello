defmodule ImageProcessing.TaskKeeper do
  @moduledoc """
  Keeps a list of photo processing tasks.
  To be run with web node.
  To be discovered by ImageProcessingProducer

  Initial state orchestration should be taken elsewhere
  """

  use GenStage

  def start_link(_args), do: GenStage.start_link(__MODULE__, [], name: __MODULE__)

  def process(list) when is_list(list), do: GenStage.cast(__MODULE__, {:tasks, list})
  def process(one), do: process([one])

  def init(initial_state) do
    {:producer, initial_state}
  end

  def handle_demand(_demand, state) do
    [] |> noreply(state)
  end

  def handle_cast({:tasks, tasks}, state) do
    tasks |> noreply(state)
  end

  defp noreply(tasks, state), do: {:noreply, tasks, state}
end
