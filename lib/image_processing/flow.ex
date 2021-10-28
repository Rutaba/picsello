defmodule ImageProcessing.Flow do
  @moduledoc """
  Image processing pipeline
  """
  use Flow

  alias ImageProcessing.TaskProxy
  alias ImageProcessing.Tasks

  def start_link(_) do
    [TaskProxy]
    |> Flow.from_stages(max_demand: 1)
    |> Flow.map(&Tasks.stringify/1)
    |> Flow.map(&Tasks.aspect/1)
    |> Flow.map(&Tasks.preview/1)
    |> Flow.map(&Tasks.watermark/1)
    |> Flow.start_link()
  end
end
