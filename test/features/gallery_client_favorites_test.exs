defmodule Picsello.GalleryClientFavoritesTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  describe "Photographer has favorites" do
    setup %{gallery: gallery} do
      Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

      album = insert(:album, %{gallery_id: gallery.id})

      insert(:photo, client_liked: true, active: true, gallery: gallery)
      insert(:photo, album: album, gallery: gallery)

      [album: album, gallery: gallery]
    end

    feature "Remove from album dropdown-option doesn't appears in Client favorites album", %{
      session: session,
      gallery: %{id: gallery_id}
    } do
      session
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> click(css("#select"))
      |> click(button("All"))
      |> click(css("#actions"))
      |> refute_has(css("#actions li button", text: "Remove from album"))
    end

    feature "Assign to album dropdown-option appears in Client favorites album", %{
      session: session,
      gallery: %{id: gallery_id}
    } do
      session
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> click(css("#select"))
      |> click(button("All"))
      |> click(css("#actions"))
      |> assert_has(css("#actions li button", text: "Assign to album"))
      |> click(button("Assign to album"))
      |> click(css("#dropdown_item_id"))
      |> click(button("Save changes"))
      |> click(button("Yes, move"))
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> find(css("#album_name", text: "Test album"))
    end

    feature "Go to original dropdown-option doesn't appears in Client favorites album when selected multiple photos",
            %{
              session: session,
              gallery: gallery,
              album: album
            } do
      insert(:photo, client_liked: true, active: true, gallery: gallery, album: album)

      session
      |> visit("/galleries/#{gallery.id}/albums/client_liked")
      |> click(css("#select"))
      |> click(button("All"))
      |> click(css("#actions"))
      |> refute_has(css("#actions li button", text: "Go to original"))
    end

    feature "Create album with selected, works on client-favorites with no redirection", %{
      session: session,
      gallery: %{id: gallery_id}
    } do
      session
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> click(css("#select"))
      |> click(button("All"))
      |> click(css("#actions"))
      |> click(css("#actions li button", text: "Create album with selected"))
      |> fill_in(text_field("Album Name"), with: "New Test Album")
      |> wait_for_enabled_submit_button()
      |> click(button("Create new album"))
      |> assert_has(css(".item", count: 1))
    end

    feature "Click on album name under photos will redirect to it's original album", %{
      session: session,
      gallery: %{id: gallery_id}
    } do
      session
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> click(css("#select"))
      |> click(button("All"))
      |> click(css("#actions"))
      |> click(css("#actions li button", text: "Create album with selected"))
      |> fill_in(text_field("Album Name"), with: "New Test Album")
      |> wait_for_enabled_submit_button()
      |> click(button("Create new album"))
      |> assert_flash(:success, text: "Album successfully created")
      |> visit("/galleries/#{gallery_id}/albums/client_liked")
      |> assert_has(css("#album_name", text: "New Test Album"))
      |> click(css("#album_name", text: "New Test Album"))
      |> find(css("#page-scroll span span", text: "New Test Album"))
    end

    feature "Show album name when client liked image belongs to album", %{
      session: session,
      gallery: gallery,
      album: album
    } do
      insert(:photo, client_liked: true, active: true, gallery: gallery, album: album)

      session
      |> visit("/galleries/#{gallery.id}/albums/client_liked")
      |> find(css("#album_name", text: "Test album"))
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
  end

  describe "Client creates favorites" do
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
      |> force_simulate_click(css("#photo-#{List.first(photo_ids)}-liked"))
      |> visit("/galleries/#{gallery.id}/albums")
      |> assert_has(css("#albums", text: "Client Favorites", count: 0))
    end
  end
end
