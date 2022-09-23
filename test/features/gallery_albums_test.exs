defmodule Picsello.GalleryAlbumsTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.Repo

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    album = insert(:album, %{gallery_id: gallery.id}) |> Repo.preload([:photos, :thumbnail_photo])
    [album: album]
  end

  test "Albums, render albums", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css("#albums .album", count: 2))
    |> click(css("#unsorted_actions"))
    |> assert_has(css("#unsorted_actions ul li", count: 2))
    |> click(css("#actions-#{album.id}"))
    |> assert_has(css("#actions-#{album.id} ul li", count: 4))
  end

  test "Albums, create album", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(testid("add-album-popup"))
    |> click(css("span", text: "Off"))
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> click(css("#toggle-visibility"))
    |> click(button("Create new album"))
    |> assert_has(css("p", text: "Album successfully created"))
    |> find(css("#page-scroll span span", test: "Test album 2"))
  end

  test "Albums, Unsorted Photos actions dropdown, Go to unsorted photos", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#unsorted_actions"))
    |> click(css("button", text: "Go to unsorted photos"))
    |> find(css("#page-scroll span span", text: "Unsorted photos"))
  end

  test "Albums, Unsorted Photos actions dropdown, Delete all unsorted photos", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: length(photo_ids)))
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#unsorted_actions"))
    |> click(css("button", text: "Delete all unsorted photos"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css("span", text: "Drag your images or"))
  end

  test "Albums, actions dropdown, Go to album", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#actions-#{album.id}"))
    |> click(css("*[phx-click='go_to_album']", text: "Go to album"))
    |> find(css("#page-scroll span span", text: "#{album.name}"))
  end

  test "Albums, album action dropdown, album settings, update name and password", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#actions-#{album.id}"))
    |> click(css("button", text: "Go to album settings"))
    |> click(css("span", text: "Off"))
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> assert_has(css("#password", value: "#{album.password}"))
    |> click(css("#toggle-visibility"))
    |> click(button("Re-generate"))
    |> refute_has(css("#password", value: "#{album.password}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album settings successfully updated"))
  end

  def placeholder_background_image,
    do: """
    *[style="background-image: url('/images/album_placeholder.png')"]
    """

  test "Albums, album action dropdown, Edit album thumbnail", %{
    session: session,
    gallery: gallery,
    album: album
  } do
    [photo_id | _photo_ids] = insert_photo(%{gallery: gallery, album: album, total_photos: 20})

    session
    |> visit("/galleries/#{gallery.id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 2))
    |> click(css("#actions-#{album.id}"))
    |> scroll_to_bottom()
    |> click(css("button", text: "Edit album thumbnail"))
    |> click(css("#photo-#{photo_id}"))
    |> click(button("Save"))
    |> click(css("#actions-#{album.id}"))
    |> assert_has(css(placeholder_background_image(), count: 1))
  end

  test "Albums, album action dropdown, delete album", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#actions-#{album.id}"))
    |> scroll_into_view(css("#actions-#{album.id}"))
    |> click(css("#actions-#{album.id} button", text: "Delete Album"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(css("p", text: "Album deleted successfully"))

    assert current_path(session) == "/galleries/#{gallery_id}/photos"
  end

  test "Albums, mobile screen, side nav actions, overview and albums", %{
    session: session,
    gallery: %{id: gallery_id},
    album: album
  } do
    session
    |> resize_window(414, 736)
    |> visit("/galleries/#{gallery_id}")
    |> click(css("span", text: "Overview"))
    |> click(css("*[phx-click='back_to_navbar']"))
    |> assert_has(css("*[phx-click='back_to_navbar']", count: 0))
    |> click(css("*[phx-click='select_albums_dropdown']"))
    |> click(button(album.name))
  end
end
