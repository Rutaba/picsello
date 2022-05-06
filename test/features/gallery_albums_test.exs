defmodule Picsello.GalleryAlbumsTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.Repo

  setup :onboarded
  setup :authenticated

  setup %{user: user} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    organization = insert(:organization, user: user)
    client = insert(:client, organization: organization)
    job = insert(:lead, type: "wedding", client: client) |> promote_to_job()
    gallery = insert(:gallery, %{job: job, total_count: 20})
    album = insert(:album, %{gallery_id: gallery.id}) |> Repo.preload([:photos, :thumbnail_photo])

    [gallery: gallery, album: album]
  end

  test "Albums, render albums", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> assert_has(css("#albums .album", count: 2))
    |> click(css("#unsorted_actions"))
    |> assert_has(css("#unsorted_actions ul li", count: 2))
    |> click(css("#actions"))
    |> assert_has(css("#actions ul li", count: 4))
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
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album successfully created"))
    |> find(css("#albums .album", count: 3))
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
    |> click(css("#actions"))
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
    |> click(css("#actions"))
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
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 20})

    session
    |> visit("/galleries/#{gallery.id}/albums")
    |> assert_has(css(placeholder_background_image(), count: 2))
    |> click(css("#actions"))
    |> click(css("button", text: "Edit album thumbnail"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> click(css("#actions"))
    |> assert_has(css(placeholder_background_image(), count: 1))
  end

  test "Albums, album action dropdown, delete album", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums")
    |> click(css("#actions"))
    |> click(button("Delete Album"))
    |> within_modal(&click(&1, button("Yes, delete")))
    |> assert_has(css("p", text: "Album deleted successfully"))

    assert current_path(session) == "/galleries/#{gallery_id}/photos"
  end
end
