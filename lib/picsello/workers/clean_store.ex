defmodule Picsello.Workers.CleanStore do
  use Oban.Worker, queue: :storage

  require Logger

  alias Picsello.Galleries.Workers.PhotoStorage

  def perform(%Oban.Job{args: %{"path" => path}}) when nil != path do
    PhotoStorage.delete(path)
    :ok
  end

  def perform(x) do
    Logger.warn("Unknown job format #{inspect(x)}")
    :ok
  end
end
