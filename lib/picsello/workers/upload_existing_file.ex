defmodule Picsello.Workers.UploadExistingFile do
  @moduledoc "Background job to clear obsolete files in storage"
  use Oban.Worker, queue: :storage

  require Logger

  alias Picsello.Galleries.Workers.PhotoStorage

  def perform(%Oban.Job{args: %{"ex_path" => path, "new_path" => new_path}}) when nil != path do
    {:ok, %{body: body}} = PhotoStorage.get_binary(path)
    {:ok, _} = PhotoStorage.insert(new_path, body)

    :ok
  end

  def perform(x) do
    Logger.warn("Unknown job format #{inspect(x)}")
    :ok
  end
end
