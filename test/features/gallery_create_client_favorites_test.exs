defmodule Picsello.GalleryCreateClientFavoritesTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    photo_ids = insert_photo(%{gallery: gallery, total_photos: 5})

    [gallery: gallery, photo_ids: photo_ids, photos_count: length(photo_ids)]
  end

  feature "Create Client Favourite Album", %{
    session: session,
    gallery: gallery,
    photo_ids: photo_ids,
    photos_count: photos_count
  } do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("#view-gallery"))
    |> assert_has(css(".item", count: photos_count))
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> visit("/galleries/#{gallery.id}/albums")
    |> find(css("#albums", count: 1, text: "Client Favorites"))
  end

  feature "Show All photos if photo doesn't belongs to album", %{
    session: session,
    gallery: gallery,
    photo_ids: photo_ids
  } do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("#view-gallery"))
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> visit("/galleries/#{gallery.id}/albums/client_liked")
    |> find(css("#album_name", text: "All photos"))
  end

  feature "Show Unsorted photos if photo doesn't belongs to album", %{
    session: session,
    gallery: gallery
  } do
    insert(:album, %{gallery_id: gallery.id})
    insert(:photo, client_liked: true, active: true, gallery: gallery)

    session
    |> visit("/galleries/#{gallery.id}/albums/client_liked")
    |> find(css("#album_name", text: "Unsorted photos"))
  end

  feature "Remove Client Favourite Album", %{
    session: session,
    gallery: gallery,
    photo_ids: photo_ids
  } do
    insert(:album, %{gallery_id: gallery.id})

    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("#view-gallery"))
    |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-to-like"))
    |> visit("/galleries/#{gallery.id}/albums")
    |> assert_has(css("#albums", count: 1, text: "Client Favorites"))
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_text(gallery.name)
    |> find(css("#item-#{List.first(photo_ids)}"), &click(&1, css(".likeBtn")))
    |> visit("/galleries/#{gallery.id}/albums")
    |> assert_has(css("#albums", text: "Client Favorites", count: 0))
  end
end
