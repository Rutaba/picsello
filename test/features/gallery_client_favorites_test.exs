defmodule Picsello.GalleryClientFavoritesTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

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

  feature "Create album with selected, works on client-favorites with no redirection", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    create_album_from_client_favorites(session, gallery_id)
    |> assert_has(button("New Test Album"))
    |> assert_url_contains("/client_liked")
    |> click(button("New Test Album"))
    |> assert_has(css(".item", count: 1))
  end

  defp create_album_from_client_favorites(session, gallery_id) do
    open_are_you_sure_modal(session, gallery_id)
    |> assert_has(css("h1", text: "Are you sure?"))
    |> assert_has(
      css("p", text: "You really want to create a new album with these selected photos?")
    )
    |> click(button("Save changes"))
  end

  defp open_are_you_sure_modal(session, gallery_id) do
    session
    |> visit("/galleries/#{gallery_id}/albums/client_liked")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(css("#actions li button", text: "Create album with selected"))
    |> fill_in(text_field("Album Name"), with: "New Test Album")
    |> wait_for_enabled_submit_button()
    |> click(button("Create new album"))
  end
end
