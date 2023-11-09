defmodule Picsello.Workers.PackGallery do
  @moduledoc "Background job to make sure gallery packs have the latest images"
  use Oban.Worker,
    unique: [states: ~w[available scheduled executing retryable]a, fields: [:args, :worker]]

  require Logger

  alias Picsello.{Pack, Galleries, Albums, Workers.PackDigitals, Repo}

  @cooldown Application.compile_env(:picsello, :gallery_pack_cooldown_seconds, 60)

  def perform(%Oban.Job{args: %{"album_id" => album_id}}) do
    album = Albums.get_album!(album_id)

    PackDigitals.broadcast(album, :ok, %{packable: album, status: :uploading})

    album
    |> Pack.url()
    |> case do
      {:ok, _url} ->
        Pack.delete(album)

      {:error, _} ->
        PackDigitals.cancel(album)
    end

    Logger.info("[Enqueue] PackDigitals for album: #{album_id}")

    PackDigitals.enqueue(album, replace: [:scheduled_at], schedule_in: @cooldown)

    :ok
  end

  def perform(%Oban.Job{args: %{"gallery_id" => gallery_id}}) do
    gallery = Galleries.get_gallery!(gallery_id)

    PackDigitals.broadcast(gallery, :ok, %{packable: gallery, status: :uploading})

    gallery
    |> Pack.url()
    |> case do
      {:ok, _url} ->
        Pack.delete(gallery)

      {:error, _} ->
        PackDigitals.cancel(gallery)
    end

    Logger.info("[Enqueue] PackDigitals for gallery: #{gallery_id}")

    PackDigitals.enqueue(gallery, replace: [:scheduled_at], schedule_in: @cooldown)

    :ok
  end

  def enqueue(gallery) do
    gallery_with_albums = Repo.preload(gallery, :albums)

    if can_download_all?(gallery) do
      __MODULE__.new(%{gallery_id: gallery.id})
      |> Oban.insert()
    end

    if Enum.any?(gallery_with_albums.albums) do
      gallery_with_albums.albums
      |> Enum.each(fn album ->
        case album do
          %{is_proofing: true, is_finals: false} ->
            Logger.info(
              "[Enqueue] PackDigitals no pack because album is proofing selections: #{album.id}"
            )

            :ok

          _ ->
            __MODULE__.new(%{album_id: album.id})
            |> Oban.insert()
        end
      end)
    end
  end

  defdelegate can_download_all?(gallery), to: Picsello.Orders
end
