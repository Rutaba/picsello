defmodule Picsello.Galleries.PhotoProcessing.ProcessingManager do
  @moduledoc """
  Sends Tasks for Cloud Function to process
  """
  require Logger

  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.Context

  def start_processing(%Photo{} = photo) do
    task = Context.simple_task_by_photo(photo)
    topic = Application.get_env(:picsello, :photo_processing_input_topic)

    result =
      Kane.Message.publish(
        %Kane.Message{data: task},
        %Kane.Topic{name: topic}
      )

    case result do
      {:ok, _return} ->
        Logger.info("Sent photo to processing #{inspect(task)}")

      err ->
        Logger.error("Error sending photo to processing #{inspect(err)} \n #{inspect(task)}")
    end
  end
end
