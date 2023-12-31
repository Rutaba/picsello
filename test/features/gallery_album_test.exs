defmodule Picsello.GalleryAlbumTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    album = insert(:album, %{gallery_id: gallery.id})
    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 20})
    gallery_digital_pricing = insert(:gallery_digital_pricing, gallery: gallery)

    insert_photo(%{gallery: gallery, album: proofing_album, total_photos: 1})
    insert(:email_preset, type: :gallery, state: :proofs_send_link)

    [
      album: album,
      photo_ids: photo_ids,
      photos_count: length(photo_ids),
      proofing_album: proofing_album,
      gallery_digital_pricing: gallery_digital_pricing
    ]
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
    |> assert_has(css("#addPhoto-form-#{gallery_id}"))
  end

  test "Album, album settings, update name", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#actions"))
    |> click(testid("edit-album-settings"))
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album settings successfully updated"))
  end

  test "Album, album settings, delete gallery", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#actions"))
    |> click(testid("edit-album-settings"))
    |> click(button("Delete"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 2))
  end

  test "Albums, Action dropdown disabled when no photo selected", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#actions"))
    |> assert_has(css(".pointer-events-none", count: 1))
  end

  test "Albums, Action dropdown with photo selected", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> refute_has(css(".pointer-events-none"))
    |> assert_has(css("#actions li button", text: "Delete"))
  end

  test "Albums, album action dropdown, Edit album thumbnail", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album,
    photo_ids: photo_ids
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 3))
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}/")
    |> click(testid("edit-album-thumbnail"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album thumbnail successfully updated"))
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 2))
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
    |> assert_has(testid("photo-count", text: Integer.to_string(photos_count)))
    |> assert_has(testid("photo-count", text: "21"))
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-view"))
    |> assert_text("/images/print.png")
  end

  test "Album, delete single photo", %{
    session: session,
    gallery: %{id: gallery_id},
    album: %{id: album_id},
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album_id}")
    |> assert_has(css(".item", count: photos_count))
    |> assert_has(testid("photo-count", text: Integer.to_string(photos_count)))
    |> click(css("#select"))
    |> click(button("None"))
    |> assert_has(css("#item-#{List.first(photo_ids)}"))
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-remove"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> refute_has(css("#photo-#{List.first(photo_ids)}-remove"))
    |> assert_has(css("p", text: "1 photo deleted successfully"))
    |> assert_has(testid("photo-count", text: "20"))
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
    |> assert_has(testid("photo-count", text: Integer.to_string(photos_count)))
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(css("#actions li button", text: "Delete"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(css("p", text: "#{photos_count} photos deleted successfully"))
    |> assert_has(css("#dragDrop-upload-form-#{gallery_id}"))
    |> assert_has(testid("photo-count", text: "1", count: 2))
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
    |> within_modal(&click(&1, button("Yes, remove")))
    |> assert_has(
      css("p", text: "#{photos_count} photos successfully removed from #{album.name}")
    )
    |> assert_has(css("#drag-drop-#{gallery_id}"))
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: photos_count))
    |> assert_has(testid("photo-count", text: Integer.to_string(photos_count)))
    |> assert_has(testid("photo-count", text: "21"))
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
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> click(css("#toggle_favorites"))
    |> assert_has(css(".item", count: 1))
    |> click(css("#toggle_favorites"))
    |> assert_has(css(".item", count: photos_count))
    |> assert_has(testid("photo-count", text: Integer.to_string(photos_count)))
    |> assert_has(testid("photo-count", text: "21"))
  end

  test "Albums, render proofing album", %{
    session: session,
    proofing_album: proofing_album,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{proofing_album.id}")
    |> assert_has(testid("edit-album-settings"))
    |> assert_has(css("#addPhoto-form-#{gallery_id}"))
  end
end
