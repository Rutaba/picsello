defmodule Picsello.Galleries.PhotoProcessing.Context do
  @moduledoc """
  Operates structures Cloud Function uses to get task and output result

  Task ---> Cloud Function ---> Context(Task, Artifacts)

  Task represents image processing task sent by BE to Cloud Function
  Context consists of Task and Artifacts.
  Cloud Function returns Context.
  Artifacts is the structure Cloud Function puts its inner state and results(like aspect ratio)
  """

  alias Picsello.Galleries
  alias Picsello.Galleries.Photo

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  @output_topic Application.compile_env(:picsello, :photo_processing_output_topic)

  def simple_task_by_photo(%Photo{} = photo) do
    %{
      "PID" => serialize(self()),
      "photoId" => photo.id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => Photo.preview_path(photo)
    }
  end

  def save_processed(%{
        "task" => %{"photoId" => photo_id, "previewPath" => preview_url},
        "artifacts" => %{"isPreviewUploaded" => true, "aspectRatio" => aspect_ratio}
      }) do
    photo = Galleries.get_photo(photo_id)

    {:ok, _} =
      Galleries.update_photo(photo, %{
        aspect_ratio: aspect_ratio,
        preview_url: preview_url
      })
  end

  def notify_processed(%{"task" => %{"PID" => serialized_pid}} = context) do
    serialized_pid
    |> deserialize()
    |> send({:photo_processed, context})
  rescue
    _err ->
      :ignored
  end

  def notify_processed(_), do: :ignored

  @spec serialize(term) :: binary
  defp serialize(term) do
    term
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  @spec deserialize(binary) :: term
  defp deserialize(str) when is_binary(str) do
    str
    |> Base.url_decode64!()
    |> :erlang.binary_to_term()
  end
end
