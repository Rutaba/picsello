defmodule Picsello.GalleryFinalsAlbumTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    finals_album = insert(:album, %{gallery_id: gallery.id, is_finals: true})
    insert_photo(%{gallery: gallery, album: finals_album, total_photos: 5})

    insert(:email_preset, type: :gallery, state: :album_send_link)

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    [finals_album: finals_album]
  end

  feature "Photographer renders finals album", %{
    session: session,
    finals_album: album,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(css("span", text: "#{album.name}", count: 3))
  end
end
