defmodule Picsello.Galleries.PhotoProcessing.ProcessingManager do
  @moduledoc """
  Sends Tasks for Cloud Function to process
  """
  require Logger

  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.Context
  alias Picsello.Galleries.PhotoProcessing.Waiter
  alias Picsello.Galleries.Watermark
  alias Picsello.GlobalGallerySettings.Photo, as: GlobalPhoto

  def start(photo, watermark \\ nil)

  def start(%Photo{} = photo, nil) do
    Context.simple_task_by_photo(photo) |> send()
    Waiter.start_tracking(photo.gallery_id, photo.id)
  end

  def start(%Photo{} = photo, watermark) do
    Context.full_task_by_photo(photo, watermark) |> send()
    Waiter.start_tracking(photo.gallery_id, photo.id)
  end

  def update_watermark(%Photo{} = photo, %Watermark{} = watermark) do
    Context.watermark_task_by_photo(photo, watermark) |> send()
    Waiter.start_tracking(photo.gallery_id, photo.id)
  end

  def update_watermark(%GlobalPhoto{} = global_photo) do
    Context.watermark_task_by_global_photo(global_photo) |> send()
  end

  def process_cover_photo(path),
    do: Context.task_by_cover_photo(path) |> send()

  defp send(task) do
    topic = Application.get_env(:picsello, :photo_processing_input_topic)

    result =
      Kane.Message.publish(
        %Kane.Message{data: task},
        %Kane.Topic{name: topic}
      )

    case result do
      {:ok, _return} ->
        Logger.debug("Sent photo to processing #{inspect(task)}")

      err ->
        Logger.error("Error sending photo to processing #{inspect(err)} \n #{inspect(task)}")
    end
  end
end
