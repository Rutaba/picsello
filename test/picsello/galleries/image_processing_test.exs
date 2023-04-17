defmodule Picsello.Galleries.ImageProcessingTest do
  use Picsello.DataCase

  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.Context
  alias Picsello.Galleries.Watermark

  @original_path "test/path/here"

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization)
          )
      )

    insert(:global_gallery_settings, organization: organization)

    [
      photo: %Photo{gallery_id: gallery.id, original_url: @original_path, name: "test.jpg"},
      watermark: %Watermark{gallery_id: gallery.id, type: :image},
      gallery: gallery
    ]
  end

  describe "fix image processing data structures" do
    test "simple task", %{photo: photo, gallery: gallery} do
      assert match?(
               %{
                 "bucket" => _,
                 "originalPath" => @original_path,
                 "previewPath" => _,
                 "pubSubTopic" => _
               },
               task = Context.simple_task_by_photo(photo)
             )

      assert task["previewPath"] |> String.starts_with?("galleries/#{gallery.id}/preview/")
    end

    test "full task", %{photo: photo, watermark: watermark, gallery: gallery} do
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

      assert task["previewPath"] |> String.starts_with?("galleries/#{gallery.id}/preview/")

      assert task["watermarkedOriginalPath"]
             |> String.starts_with?("galleries/#{gallery.id}/watermarked/")

      assert task["watermarkedPreviewPath"]
             |> String.starts_with?("galleries/#{gallery.id}/watermarked_preview/")
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
      text_watermark = %{watermark | type: :text, text: "text mark"}

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
