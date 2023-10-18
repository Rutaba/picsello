defmodule Picsello.Galleries.PhotoProcessing.ProcessedConsumer do
  @moduledoc """
  Consumes responses from Cloud Function
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Picsello.Galleries.PhotoProcessing.Context
  alias Picsello.Galleries.PhotoProcessing.Waiter
  alias Picsello.GlobalSettings
  alias Picsello.Workers.CleanStore
  alias Ecto.Changeset
  alias Picsello.Repo
  alias Phoenix.PubSub

  def start_link(opts) do
    producer_module = Keyword.fetch!(opts, :producer_module)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: producer_module],
      processors: [
        default: [concurrency: 10]
      ]
    )
  end

  def handle_message(_, %Message{} = message, _) do
    with {:ok, data} <- Jason.decode(message.data),
         :ok <- do_handle_message(data) do
      Message.update_data(message, fn _ -> data end)
    else
      {:error, :unknown_context_structure} ->
        Logger.error("Unknown message structure in " <> message.data)
        message

      err ->
        msg = "Failed to process PubSub message\n#{inspect(err)}\n\n#{inspect(message)}"
        Logger.error(msg)
        message
    end
  end

  defp do_handle_message(%{
         "task" =>
           %{
             "globalWatermarkPreview" => true,
             "isSavePreview" => is_save_preview,
             "watermarkedPreviewPath" => watermarked_preview_path,
             "watermarkedOriginalPath" => watermarked_original_path,
             "organizationId" => organization_id
           } = task
       }) do
    is_save_preview
    |> then(fn
      true ->
        organization_id
        |> GlobalSettings.get()
        |> Changeset.change(%{global_watermark_path: watermarked_preview_path})
        |> Repo.update!()

        [watermarked_original_path]

      false ->
        [watermarked_preview_path, watermarked_original_path]
    end)
    |> Enum.map(
      &CleanStore.new(%{path: &1}, scheduled_at: Timex.shift(DateTime.utc_now(), hours: 1))
    )
    |> Oban.insert_all()

    PubSub.broadcast(
      Picsello.PubSub,
      "preview_watermark:#{organization_id}",
      {:preview_watermark, task}
    )

    :ok
  end

  defp do_handle_message(%{"task" => task} = context) do
    with {:ok, photo} <- Context.save_processed(context) do
      task
      |> case do
        %{"photoId" => photo_id} ->
          Waiter.complete_tracking(photo.gallery_id, photo.id)
          "Photo has been processed [#{photo_id}]"

        %{"processCoverPhoto" => true, "originalPath" => path} ->
          "Cover photo [#{path}] has been processed"
      end
      |> Logger.info()

      Context.notify_processed(context, photo)

      :ok
    end
  end

  defp do_handle_message(%{"path" => "" <> path, "metadata" => %{"version-id" => "" <> id}}) do
    Picsello.Profiles.handle_photo_processed_message(path, id)
  end
end
