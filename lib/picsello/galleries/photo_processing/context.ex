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
  alias Picsello.Galleries.CoverPhoto
  alias Picsello.Galleries.Photo
  alias Picsello.GlobalSettings.Gallery, as: GSGallery
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
    gallery = Picsello.Repo.get_by!(Picsello.Galleries.Gallery, id: watermark.gallery_id)
    organization = load_organization(gallery)
    global_settings = Picsello.Repo.get_by(GSGallery, organization_id: organization.id)
    watermark_path = path(gallery, global_settings, watermark, organization)

    %{
      "photoId" => photo.id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => Photo.preview_path(photo),
      "watermarkedPreviewPath" => Photo.watermarked_preview_path(photo),
      "watermarkedOriginalPath" => Photo.watermarked_path(photo),
      "watermarkPath" => watermark_path,
      "watermarkText" => watermark.type == :text && watermark.text
    }
  end

  def watermark_photo_task_by_global_photo(
        %GSGallery.Photo{} = photo,
        organization_id
      ) do
    watermark_path = "galleries/#{organization_id}/watermark.png"

    %{
      "is_image" => true,
      "photoId" => photo.id,
      "user_id" => photo.user_id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => nil,
      "watermarkedPreviewPath" => GSGallery.watermarked_path(),
      "watermarkedOriginalPath" => GSGallery.watermarked_path(),
      "watermarkPath" => watermark_path,
      "watermarkText" => nil
    }
  end

  def watermark_task_by_photo(%Photo{} = photo, %Watermark{} = watermark) do
    photo
    |> full_task_by_photo(watermark)
    |> Map.drop(["previewPath"])
  end

  def watermark_task_by_global_photo(%GSGallery.Photo{} = photo) do
    %{
      "is_global" => true,
      "photoId" => photo.id,
      "user_id" => photo.user_id,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => photo.original_url,
      "previewPath" => nil,
      "watermarkedPreviewPath" => GSGallery.watermarked_path(),
      "watermarkedOriginalPath" => GSGallery.watermarked_path(),
      "watermarkPath" => nil,
      "watermarkText" => photo.text
    }
  end

  def task_by_cover_photo(path) do
    %{
      "processCoverPhoto" => true,
      "bucket" => @bucket,
      "pubSubTopic" => @output_topic,
      "originalPath" => path
    }
  end

  defp load_organization(gallery) do
    gallery
    |> Picsello.Repo.preload([job: [client: :organization]], force: true)
    |> extract_organization()
  end

  defp extract_organization(%{job: %{client: %{organization: organization}}}), do: organization

  def save_processed(context), do: do_save_processed(context)

  defp do_save_processed(%{
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
    Galleries.update_photo(photo_id, %{
      aspect_ratio: aspect_ratio,
      height: height,
      width: width,
      preview_url: preview_url,
      watermarked_url: watermark_path,
      watermarked_preview_url: watermarked_preview_path
    })
  end

  defp do_save_processed(%{
         "task" => %{"photoId" => photo_id, "previewPath" => preview_url},
         "artifacts" => %{
           "isPreviewUploaded" => true,
           "aspectRatio" => aspect_ratio,
           "height" => height,
           "width" => width
         }
       }) do
    Galleries.update_photo(photo_id, %{
      aspect_ratio: aspect_ratio,
      height: height,
      width: width,
      preview_url: preview_url
    })
  end

  defp do_save_processed(%{
         "task" => %{
           "photoId" => photo_id,
           "watermarkedPreviewPath" => watermarked_preview_path,
           "watermarkedOriginalPath" => watermark_path
         },
         "artifacts" => %{
           "isWatermarkedUploaded" => true
         }
       }) do
    Galleries.update_photo(photo_id, %{
      watermarked_url: watermark_path,
      watermarked_preview_url: watermarked_preview_path
    })
  end

  defp do_save_processed(%{
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
    |> case do
      {:ok, %{cover_photo: photo}} -> {:ok, photo}
      error -> error
    end
  end

  def notify_processed(context, %Photo{} = photo) do
    Galleries.broadcast(%{id: photo.gallery_id}, {:photo_processed, context, photo})
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

  defp path(%{use_global: %{watermark: true}}, %{}, %{type: :image}, organization),
    do: GSGallery.watermark_path(organization.id)

  defp path(%{id: id}, _, %{type: :image}, _), do: Watermark.watermark_path(id)
  defp path(_gallery, _, _, _), do: nil
end
