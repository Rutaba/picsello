defmodule Picsello.GalleryPhotosDownloadTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    [photo_ids: photo_ids, photos_count: length(photo_ids)]
  end

  test "downloads selected photos", %{
    session: session,
    gallery: %{id: gallery_id, client_link_hash: client_link_hash},
    photo_ids: photo_ids
  } do
    link = Routes.gallery_downloads_path(
      PicselloWeb.Endpoint,
      :download_all,
      client_link_hash,
      encode(photo_ids)
      )
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> find(
        link("Download photos"),
        &assert(Element.attr(&1, "href") =~ link)
      )
     end

     test "downloads single photo", %{
    session: session,
    gallery: %{id: gallery_id, client_link_hash: client_link_hash},
    photo_ids: photo_ids
  } do
    link = Routes.gallery_downloads_path(
      PicselloWeb.Endpoint,
      :download_photo,
      client_link_hash,
      List.first(photo_ids),
      is_photographer: true
      )
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> force_simulate_click(css("#meatball-photo-#{List.first(photo_ids)}"))
    |> find(
        css("#download-photo-#{List.first(photo_ids)}"),
        &assert(Element.attr(&1, "href") =~ link)
      )
     end

  def encode(photo_ids) do
  {_, photo_ids} = Jason.encode(photo_ids)
  photo_ids
  end
end
