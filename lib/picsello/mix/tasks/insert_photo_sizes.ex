defmodule Mix.Tasks.InsertPhotoSizes do
  @moduledoc false

  use Mix.Task
  import Ecto.Query
  alias Picsello.{Photos, Repo, Galleries.Workers.PhotoStorage}

  require Logger

  @shortdoc "Insert photo sizes"
  def run(_) do
    load_app()

    photos = get_all_photos()

    if Enum.any?(photos) do
      assure_photo_size(photos)
      Mix.Tasks.InsertPhotoSizes.run(nil)
    end
  end

  defp assure_photo_size(without_size) do
    Logger.info("photo count: #{Enum.count(without_size)}")

    without_size
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk ->
      chunk
      |> Task.async_stream(
        fn %{original_url: url, id: id} ->
          url = PhotoStorage.path_to_url(url)
          Logger.info("Photo fetched with id #{id} and url #{url}")

          case Tesla.get(url) do
            {:ok, %{status: 200, body: body}} -> %{id: id, size: byte_size(body)}
            _ -> %{id: id, size: 123_456}
          end
        end,
        timeout: :infinity
      )
      |> Enum.map(&elem(&1, 1))
      |> then(&Photos.update_photos_in_bulk(chunk, &1))
    end)

    # without_size
    # |> Enum.chunk_every(10)
    # |> Enum.each(fn chunk ->
    #   chunk
    #   |> Enum.each(fn %{original_url: url, id: id} ->
    # url = PhotoStorage.path_to_url(url)
    # Logger.info("Photo fetched with id #{id} and url #{url}")

    # case Tesla.get(url) do
    #   {:ok, %{status: 200, body: body}} -> %{id: id, size: byte_size(body)}
    #   _ -> %{id: id, size: 123_456}
    # end
    #   end)
    #   |> Enum.map(&elem(&1, 1))
    #   |> then(&Photos.update_photos_in_bulk(chunk, &1))
    # end)
  end

  defp get_all_photos() do
    from(p in Photos.active_photos(), limit: 1000, where: is_nil(p.size))
    |> Repo.all()
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
