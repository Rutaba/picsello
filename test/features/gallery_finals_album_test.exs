defmodule Picsello.GalleryFinalsAlbumTest do
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
    |> assert_has(button("Send album to client"))
  end

  test "Finals Albums, send album to client", %{
    session: session,
    gallery: %{id: gallery_id},
    finals_album: album
  } do
    session
    |> visit("/galleries/#{gallery_id}/albums/#{album.id}")
    |> click(testid("send-proofs-popup"))
    |> assert_has(css("button", text: "Send Email"))
    |> click(css("button", text: "Send Email"))
    |> assert_has(css("p", text: "Album shared!"))
  end
end
