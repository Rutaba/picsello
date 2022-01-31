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
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.Watermark

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)
  @output_topic Application.compile_env(:picsello, :photo_processing_output_topic)

  def simple_task_by_photo(%Photo{} = photo) do
    %{
      "photoId" => photo.id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => Photo.preview_path(photo)
    }
  end

  def full_task_by_photo(%Photo{} = photo, %Watermark{} = watermark) do
    watermark_path =
      if watermark.type == "image" do
        "galleries/#{watermark.gallery_id}/watermark.png"
      else
        nil
      end

    %{
      "photoId" => photo.id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => Photo.preview_path(photo),
      "watermarkedPreviewPath" => Photo.watermarked_preview_path(photo),
      "watermarkedOriginalPath" => Photo.watermarked_path(photo),
      "watermarkPath" => watermark_path,
      "watermarkText" => watermark.type == "text" && watermark.text
    }
  end

  def watermark_task_by_photo(%Photo{} = photo, %Watermark{} = watermark) do
    photo
    |> full_task_by_photo(watermark)
    |> Map.drop(["previewPath"])
  end

  def task_by_cover_photo(path) do
    %{
      "processCoverPhoto" => true,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => path
    }
  end

  def save_processed(%{
        "task" => %{
          "photoId" => photo_id,
          "previewPath" => preview_url,
          "watermarkedPreviewPath" => watermarked_preview_path,
          "watermarkedOriginalPath" => watermark_path
        },
        "artifacts" => %{
          "isPreviewUploaded" => true,
          "aspectRatio" => aspect_ratio,
          "height" => height,
          "width" => width,
          "isWatermarkedUploaded" => true
        }
      }) do
    photo = Galleries.get_photo(photo_id)

    {:ok, _} =
      Galleries.update_photo(photo, %{
        aspect_ratio: aspect_ratio,
        height: height,
        width: width,
        preview_url: preview_url,
        watermarked_url: watermark_path,
        watermarked_preview_url: watermarked_preview_path
      })
  end

  def save_processed(%{
        "task" => %{"photoId" => photo_id, "previewPath" => preview_url},
        "artifacts" => %{
          "isPreviewUploaded" => true,
          "aspectRatio" => aspect_ratio,
          "height" => height,
          "width" => width
        }
      }) do
    photo = Galleries.get_photo(photo_id)

    {:ok, _} =
      Galleries.update_photo(photo, %{
        aspect_ratio: aspect_ratio,
        height: height,
        width: width,
        preview_url: preview_url
      })
  end

  def save_processed(%{
        "task" => %{
          "photoId" => photo_id,
          "watermarkedPreviewPath" => watermarked_preview_path,
          "watermarkedOriginalPath" => watermark_path
        },
        "artifacts" => %{
          "isWatermarkedUploaded" => true
        }
      }) do
    photo = Galleries.get_photo(photo_id)

    {:ok, _} =
      Galleries.update_photo(photo, %{
        watermarked_url: watermark_path,
        watermarked_preview_url: watermarked_preview_path
      })
  end

  def save_processed(%{
        "task" => %{
          "processCoverPhoto" => true,
          "originalPath" => path
        },
        "artifacts" => %{
          "aspectRatio" => aspect_ratio,
          "width" => width,
          "height" => height
        }
      }) do
    path
    |> CoverPhoto.get_gallery_id_from_path()
    |> Galleries.get_gallery!()
    |> Galleries.save_gallery_cover_photo(%{
      cover_photo: %{id: path, aspect_ratio: aspect_ratio, width: width, height: height}
    })
    |> then(fn %{cover_photo: photo} -> {:ok, photo} end)
  rescue
    _ -> :error
  end

  def notify_processed(context, %Photo{} = photo) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "gallery:#{photo.gallery_id}",
      {:photo_processed, context, photo}
    )
  rescue
    _err ->
      :ignored
  end

  def notify_processed(context, %CoverPhoto{} = photo) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "gallery:#{photo.gallery_id}",
      {:cover_photo_processed, context, photo}
    )
  rescue
    _err ->
      :ignored
  end

  def notify_processed(_), do: :ignored
end
