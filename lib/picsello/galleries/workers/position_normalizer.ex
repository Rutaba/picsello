defmodule Picsello.Galleries.Workers.PositionNormalizer do
  @moduledoc """
  Debounce photo position normalization within a gallery
  """
  use GenServer

  import PicselloWeb.LiveHelpers, only: [noreply: 1]

  alias Picsello.Galleries

  @timeout 30_000

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  def normalize(gallery_id), do: GenServer.cast(__MODULE__, {:normalize, gallery_id})

  @impl true
  def handle_cast({:normalize, gallery_id}, timers) do
    timers
    |> Map.get(gallery_id)
    |> cancel_timer()

    timers
    |> Map.put(gallery_id, Process.send_after(self(), {:do_normalize, gallery_id}, @timeout))
    |> noreply()
  end

  @impl true
  def handle_info({:do_normalize, gallery_id}, timers) do
    Galleries.normalize_gallery_photo_positions(gallery_id)

    timers
    |> Map.drop([gallery_id])
    |> noreply()
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
end
