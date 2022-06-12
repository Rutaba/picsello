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

  describe "get_related" do
    test "gets all other photos in the gallery" do
      _other_gallery_photo = insert(:photo)

      [photo | [%{id: same_gallery_photo}]] = insert_list(2, :photo, gallery: insert(:gallery))

      assert [%{id: ^same_gallery_photo}] = Photos.get_related(photo)
    end

    test "photos in the same album come first, ordered by position" do
      gallery = insert(:gallery)

      %{id: no_album} = insert(:photo, gallery: gallery)

      same_album = insert(:album, gallery: gallery)

      [photo | [%{id: first_same_album}, %{id: second_same_album}]] =
        for position <- 1..3 do
          insert(:photo, album: same_album, gallery: gallery, position: position)
        end

      %{id: other_album} =
        insert(:photo, album: insert(:album, gallery: gallery), gallery: gallery)

      assert [first_same_album, second_same_album, other_album, no_album] ==
               photo |> Photos.get_related() |> Enum.map(& &1.id)
    end

    test "filters to favorites" do
      gallery = insert(:gallery)
      %{id: liked_photo} = insert(:photo, gallery: gallery, client_liked: true)
      [photo | _disliked] = insert_list(2, :photo, gallery: gallery, client_liked: false)

      assert [^liked_photo] =
               photo |> Photos.get_related(favorites_only: true) |> Enum.map(& &1.id)
    end
  end
end
