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
         :ok <- handle_completed_context(data) do
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

  def handle_completed_context(%{"task" => %{"photoId" => photo_id}} = context) do
    {:ok, photo} = Context.save_processed(context)
    Waiter.complete_tracking(photo.gallery_id, photo.id)

    Logger.info("Photo has been processed [#{photo_id}]")
    Context.notify_processed(context, photo)

    :ok
  rescue
    _ -> :error
  end

  def handle_completed_context(
        %{"task" => %{"processCoverPhoto" => true, "originalPath" => path}} = context
      ) do
    {:ok, photo} = Context.save_processed(context)
    Logger.info("Cover photo [#{path}] has been processed")
    Context.notify_processed(context, photo)

    :ok
  rescue
    _ -> :error
  end

  def handle_completed_context(_), do: {:error, :unknown_context_structure}
end
