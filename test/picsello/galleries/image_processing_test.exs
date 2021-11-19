defmodule Picsello.Galleries.ImageProcessingTest do
  use ExUnit.Case, async: true

  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.Context
  alias Picsello.Galleries.Watermark

  @gallery_id 1234
  @original_path "test/path/here"

  setup_all do
    [
      photo: %Photo{gallery_id: @gallery_id, original_url: @original_path, name: "test.jpg"},
      watermark: %Watermark{gallery_id: @gallery_id, type: "image"}
    ]
  end

  describe "fix image processing data structures" do
    test "simple task", %{photo: photo} do
      assert match?(
               %{
                 "bucket" => _,
                 "originalPath" => @original_path,
                 "previewPath" => _,
                 "pubSubTopic" => _
               },
               task = Context.simple_task_by_photo(photo)
             )

      assert task["previewPath"] |> String.starts_with?("galleries/#{@gallery_id}/preview/")
    end

    test "full task", %{photo: photo, watermark: watermark} do
      assert match?(
               %{
                 "bucket" => _,
                 "originalPath" => @original_path,
                 "previewPath" => _,
                 "pubSubTopic" => _,
                 "watermarkPath" => _,
                 "watermarkText" => false,
                 "watermarkedOriginalPath" => _,
                 "watermarkedPreviewPath" => _
               },
               task = Context.full_task_by_photo(photo, watermark)
             )

      assert task["previewPath"] |> String.starts_with?("galleries/#{@gallery_id}/preview/")

      assert task["watermarkedOriginalPath"]
             |> String.starts_with?("galleries/#{@gallery_id}/watermarked/")

      assert task["watermarkedPreviewPath"]
             |> String.starts_with?("galleries/#{@gallery_id}/watermarked_preview/")
    end

    test "image watermark task", %{photo: photo, watermark: watermark} do
      assert match?(
               %{
                 "bucket" => _,
                 "originalPath" => @original_path,
                 "pubSubTopic" => _,
                 "watermarkPath" => _,
                 "watermarkText" => false,
                 "watermarkedOriginalPath" => _,
                 "watermarkedPreviewPath" => _
               },
               task = Context.watermark_task_by_photo(photo, watermark)
             )

      assert task |> Map.get("previewPath", :not_found) == :not_found
    end

    test "text watermark task", %{photo: photo, watermark: watermark} do
      text_watermark = %{watermark | type: "text", text: "text mark"}

      assert match?(
               %{
                 "bucket" => _,
                 "originalPath" => @original_path,
                 "pubSubTopic" => _,
                 "watermarkPath" => nil,
                 "watermarkText" => _,
                 "watermarkedOriginalPath" => _,
                 "watermarkedPreviewPath" => _
               },
               task = Context.watermark_task_by_photo(photo, text_watermark)
             )

      assert task |> Map.get("previewPath", :not_found) == :not_found
    end
  end
end
