defmodule Picsello.GalleryAlbumsTest do
  use Picsello.FeatureCase, async: true
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Galleries.Photo

  setup do
    gallery = insert(:gallery)
    album = insert(:album, %{gallery_id: gallery.id})

    [gallery: gallery, album: album]
  end

  setup :onboarded
  setup :authenticated

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
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> wait_for_enabled_submit_button()
    |> click(button("Save"))
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
    gallery: %{id: gallery_id}
  } do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    count = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 3))

    Enum.map(count, fn _ ->
      Map.get(insert_photo(gallery_id, nil, "/images/print.png"), :id)
    end)

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: 3))
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
    |> fill_in(css("#album_name"), with: "Test album 2")
    |> click(css("span", text: "Off"))
    |> assert_has(css("#password", value: "#{album.password}"))
    |> click(css("#toggle-visibility"))
    |> click(button("Re-generate"))
    |> refute_has(css("#password", value: "#{album.password}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "Album settings successfully updated"))
  end

  test "Albums, album action dropdown, Edit album thumbnail", %{
    session: session,
    gallery: gallery,
    album: album
  } do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    count = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 3))

    photo_ids =
      Enum.map(count, fn _ ->
        Map.get(insert_photo(gallery.id, album.id, "/images/print.png"), :id)
      end)

    session
    |> visit("/galleries/#{gallery.id}/albums")
    |> click(css("#actions"))
    |> assert_has(
      css("*[style='background-image: url(/images/album_placeholder.png)']", count: 2)
    )
    |> click(css("button", text: "Edit album thumbnail"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> click(css("#actions"))
    |> assert_has(
      css("*[style='background-image: url(/images/album_placeholder.png)']", count: 1)
    )
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

  def insert_photo(gallery_id, album_id, photo_url) do
    insert(%Photo{
      album_id: album_id,
      gallery_id: gallery_id,
      preview_url: photo_url,
      original_url: photo_url,
      name: photo_url,
      position: 1
    })
  end
end
