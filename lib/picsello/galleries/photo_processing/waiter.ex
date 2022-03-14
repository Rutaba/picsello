defmodule Picsello.Galleries.PhotoProcessing.Waiter do
  @moduledoc "Allows to postpone actions till gallery photo processing ends"
  use GenServer

  ## Interface

  def start_tracking(gallery_id, task_id),
    do: GenServer.cast(__MODULE__, {:track, gallery_id, task_id})

  def complete_tracking(gallery_id, task_id),
    do: GenServer.cast(__MODULE__, {:complete, gallery_id, task_id})

  def postpone(gallery_id, callback),
    do: GenServer.cast(__MODULE__, {:call, gallery_id, callback})

  ### Implementation

  @impl true
  def init(state) do
    {:ok, state}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def handle_cast({:track, gallery_id, task_id}, state) do
    {list, callbacks} = Map.get(state, gallery_id, {[], []})

    {[task_id | list], callbacks}
    |> then(&Map.put(state, gallery_id, &1))
    |> noreply()
  end

  @impl true
  def handle_cast({:call, gallery_id, callback}, state) do
    {list, callbacks} = Map.get(state, gallery_id, {[], []})

    if list |> Enum.empty?() do
      [callback | callbacks] |> run()

      {[], []}
    else
      {list, [callback | callbacks]}
    end
    |> then(&Map.put(state, gallery_id, &1))
    |> noreply()
  end

  def handle_cast({:complete, gallery_id, task_id}, state) do
    {list, callbacks} = Map.get(state, gallery_id, {[], []})

    new_list =
      list
      |> List.delete(task_id)

    if new_list == [] do
      callbacks |> run()

      state
      |> Map.drop([gallery_id])
    else
      {new_list, callbacks}
      |> then(&Map.put(state, gallery_id, &1))
    end
    |> noreply()
  end

  defp run(list), do: list |> Enum.each(& &1.())
  defp noreply(x), do: {:noreply, x}
end
