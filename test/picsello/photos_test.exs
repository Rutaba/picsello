defmodule Picsello.PhotosTest do
  use Picsello.DataCase
  alias Picsello.Photos
  import Money.Sigils

  describe "get" do
    test "watermarked is true if gallery has a watermark" do
      gallery = insert(:gallery)
      %{id: photo_id} = insert(:photo, gallery: gallery)
      insert(:watermark, gallery: gallery)

      assert %{id: ^photo_id, watermarked: true} = Photos.get(photo_id)
    end

    test "watermarked is false if gallery has no watermark" do
      gallery = insert(:gallery)
      %{id: photo_id} = insert(:photo, gallery: gallery)

      assert %{id: ^photo_id, watermarked: false} = Photos.get(photo_id)
    end

    test "watermarked is false if gallery has a watermark but photo is purchased" do
      gallery = insert(:gallery)
      %{id: photo_id} = photo = insert(:photo, gallery: gallery)
      insert(:watermark, gallery: gallery)

      insert(:order, digitals: [build(:digital, photo: photo)], placed_at: DateTime.utc_now())

      assert %{id: ^photo_id, watermarked: false} = Photos.get(photo_id)
    end

    test "watermarked is false if gallery has a watermark but bundle is purchased" do
      gallery = insert(:gallery)
      %{id: photo_id} = insert(:photo, gallery: gallery)
      insert(:watermark, gallery: gallery)

      insert(:order, gallery: gallery, bundle_price: ~M[5000]USD, placed_at: DateTime.utc_now())

      assert %{id: ^photo_id, watermarked: false} = Photos.get(photo_id)
    end

    test "watermarked is true if gallery has a watermark and order with bundle is not placed" do
      gallery = insert(:gallery)
      %{id: photo_id} = insert(:photo, gallery: gallery)
      insert(:watermark, gallery: gallery)

      insert(:order, gallery: gallery, bundle_price: ~M[5000]USD, placed_at: nil)

      assert %{id: ^photo_id, watermarked: true} = Photos.get(photo_id)
    end

    test "watermarked is true if gallery has a watermark but bundle or digital are not purchased" do
      gallery = insert(:gallery)
      %{id: photo_id} = insert(:photo, gallery: gallery)
      insert(:watermark, gallery: gallery)

      insert(:order, gallery: gallery, placed_at: DateTime.utc_now())

      assert %{id: ^photo_id, watermarked: true} = Photos.get(photo_id)
    end
  end
end