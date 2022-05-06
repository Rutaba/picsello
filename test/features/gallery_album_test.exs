defmodule Picsello.GalleryAlbumTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    total_photos = 20
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    organization = insert(:organization, user: user)
    client = insert(:client, organization: organization)
    job = insert(:lead, type: "wedding", client: client) |> promote_to_job()
    gallery = insert(:gallery, %{job: job, total_count: total_photos})
    album = insert(:album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: total_photos})

    [gallery: gallery, album: album, photo_ids: photo_ids, photos_count: length(photo_ids)]
  end

  test "Album, render album", %{
    session: session,
    album: %{id: album_id},
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
    |> assert_has(testid("edit-album-settings"))
    |> assert_has(testid("edit-album-thumbnail"))
    |> assert_has(css("#addPhoto"))
  end

  test "Album, album settings, update name and password", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#actions"))
    |> click(testid("edit-album-settings"))
    |> click(css("span", text: "Off"))
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> assert_has(css("#password", value: "#{album.password}"))
    |> click(css("#toggle-visibility"))
    |> click(button("Re-generate"))
    |> refute_has(css("#password", value: "#{album.password}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album settings successfully updated"))
  end

  test "Albums, album action dropdown, Edit album thumbnail", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album,
    photo_ids: photo_ids
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 2))
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}/")
    |> click(testid("edit-album-thumbnail"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album thumbnail successfully updated"))
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 1))
  end

  def placeholder_background_image,
    do: """
    *[style="background-image: url('/images/album_placeholder.png')"]
    """

  test "Album, photo view", %{
    session: session,
    gallery: %{id: gallery_id},
    album: %{id: album_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("None"))
    |> click(css("#photo-#{List.first(photo_ids)}-view"))
    |> click(css("#wrapper a"))
  end

  test "Album, delete signle photo", %{
    session: session,
    gallery: %{id: gallery_id},
    album: %{id: album_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("None"))
    |> assert_has(css("#item-#{List.first(photo_ids)}"))
    |> click(css("#photo-#{List.first(photo_ids)}-remove"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> refute_has(css("#photo-#{List.first(photo_ids)}-remove"))
    |> assert_has(css("p", text: "1 photo deleted successfully"))
  end

  test "Album, delete all photos", %{
    session: session,
    gallery: %{id: gallery_id},
    album: %{id: album_id},
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
    |> assert_has(css(".item", count: photos_count))
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(css("#actions li button", text: "Delete"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(css("p", text: "#{photos_count} photos deleted successfully"))
    |> assert_has(css("#dragDrop-upload-form"))
  end

  test "Album, move photos album to unsorted photos", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(button("Remove from album"))
    |> assert_has(
      css("p", text: "#{photos_count} photos successfully removed from #{album.name}")
    )
    |> assert_has(css("#drag-drop"))
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
  end

  test "Album, show favorites only", %{
    session: session,
    gallery: %{id: gallery_id},
    album: %{id: album_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
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
