defmodule Picsello.GalleryUnsortedPhotosTest do
  use Picsello.FeatureCase, async: true

  setup do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    total_photos = 20

    gallery = insert(:gallery, %{total_count: total_photos})
    album = insert(:album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, total_photos: total_photos})

    [gallery: gallery, album: album, photo_ids: photo_ids, photos_count: length(photo_ids)]
  end

  setup :onboarded
  setup :authenticated

  test "Unsorted Photos, render unsorted photos and album", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> refute_has(testid("edit-album-settings"))
    |> refute_has(testid("edit-album-thumbnail"))
    |> assert_has(css("#addPhoto"))
  end

  test "Unsorted Photos, pagination", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})
    photo_count = length(photo_ids) + 20
    per_page = 24

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: per_page))
    |> scroll_into_view(css("#gallery"))
    |> assert_has(css(".item", count: photo_count))
  end

  test "Unsorted Photos, select options", %{
    session: session,
    gallery: %{id: gallery_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("All"))
    |> assert_has(css("#selected-photos-count", text: "#{photos_count} photos selected"))
    |> click(css("#select"))
    |> click(button("None"))
    |> refute_has(css("#selected-photos-count", text: "#{photos_count} photos selected"))
    |> click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> click(css("#select"))
    |> click(button("Favorite"))
    |> assert_has(css("#selected-photos-count", text: "1 photo selected"))
    |> click(css("#select"))
    |> click(button("None"))
    |> refute_has(css("#selected-photos-count", text: "1 photos selected"))
  end

  test "Unsorted Photos, photo view", %{
    session: session,
    gallery: %{id: gallery_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("None"))
    |> click(css("#photo-#{List.first(photo_ids)}-view"))
    |> click(css("#wrapper a"))
  end

  test "Unsorted Photos, delete signle photo", %{
    session: session,
    gallery: %{id: gallery_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("None"))
    |> assert_has(css("#item-#{List.first(photo_ids)}"))
    |> click(css("#photo-#{List.first(photo_ids)}-remove"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> refute_has(css("#photo-#{List.first(photo_ids)}-remove"))
    |> assert_has(css("p", text: "1 photo deleted successfully"))
  end

  test "Unsorted Photos, delete all photos", %{
    session: session,
    gallery: %{id: gallery_id},
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(css("#actions li button", text: "Delete"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(css("p", text: "#{photos_count} photos deleted successfully"))
    |> assert_has(css("#dragDrop-upload-form"))
  end

  test "Unsorted Photos, move unsorted photos and album", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(button("Move to #{album.name}"))
    |> assert_has(css("p", text: "#{photos_count} photos successfully moved to #{album.name}"))
    |> assert_has(css("#drag-drop"))
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> assert_has(css(".item", count: photos_count))
  end

  test "Unsorted Photos, show favorites only", %{
    session: session,
    gallery: %{id: gallery_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("None"))
    |> click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> click(css("#toggle_favorites"))
    |> assert_has(css(".item", count: 1))
    |> click(css("#toggle_favorites"))
    |> assert_has(css(".item", count: photos_count))
  end
end
