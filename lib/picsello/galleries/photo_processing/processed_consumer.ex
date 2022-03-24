defmodule Picsello.Galleries.PhotoProcessing.ProcessedConsumer do
  @moduledoc """
  Consumes responses from Cloud Function
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Picsello.Galleries.PhotoProcessing.Context
  alias Picsello.Galleries.PhotoProcessing.Waiter

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

      :error ->
        Message.failed(message, "Entity not found")

      err ->
        msg = "Failed to process PubSub message\n#{inspect(err)}\n\n#{inspect(message)}"
        Logger.error(msg)
        Message.failed(message, msg)
    end
  end

  defp do_handle_message(%{"task" => task} = context) do
    {:ok, photo} = Context.save_processed(context)

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
  rescue
    _ -> :error
  end

  defp do_handle_message(%{"path" => "" <> path, "metadata" => %{"version-id" => "" <> id}}) do
    Picsello.Profiles.handle_photo_processed_message(path, id)
  end
end
