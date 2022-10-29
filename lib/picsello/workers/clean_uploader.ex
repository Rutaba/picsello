defmodule Picsello.Workers.CleanUploader do
  @moduledoc "Background job to clean uploading memory"

  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  import Ecto.Query, only: [from: 2]

  def perform(_) do
    _memory =
      Picsello.Repo.all(from u in "users", select: u.id)
      |> Enum.map(fn user_id ->
        PicselloWeb.UploaderCache.delete(user_id)
      end)

    :ok
  end
end
