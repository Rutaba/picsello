defmodule Picsello.Workers.PackGallery do
  @moduledoc "Background job to make sure gallery packs have the latest images"
  use Oban.Worker,
    unique: [states: ~w[available scheduled executing retryable]a, fields: [:args, :worker]]

  alias Picsello.{Pack, Galleries, Workers.PackDigitals}

  @cooldown Application.compile_env(:picsello, :gallery_pack_cooldown_seconds, 60)

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

    PackDigitals.enqueue(gallery, replace: [:scheduled_at], schedule_in: @cooldown)

    :ok
  end

  def enqueue(gallery) do
    if can_download_all?(gallery) do
      __MODULE__.new(%{gallery_id: gallery.id})
      |> Oban.insert()
    end
  end

  defdelegate can_download_all?(gallery), to: Picsello.Orders
end
