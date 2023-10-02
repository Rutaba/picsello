defmodule Picsello.GalleryPhotosDownloadTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  import Money.Sigils

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
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(button("Download photos"))
  end

  test "downloads single photo", %{
    session: session,
    gallery: %{id: gallery_id},
    photo_ids: photo_ids
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> find(css("#item-#{List.first(photo_ids)}"))
    |> force_simulate_click(css("#meatball-photo-#{List.first(photo_ids)}"))
    |> assert_has(css("button", text: "Download photo"))
  end

  test "render error 403 if unauthorized user", %{
    session: session
  } do
    organization = insert(:organization, user: insert(:user))
    client = insert(:client, organization: organization)
    package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)
    job = insert(:lead, type: "wedding", client: client, package: package) |> promote_to_job()
    gallery = insert(:gallery, %{job: job, total_count: 20})
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    link =
      Routes.gallery_downloads_path(
        PicselloWeb.Endpoint,
        :download_all,
        gallery.client_link_hash,
        photo_ids: Enum.join(photo_ids, ",")
      )

    session
    |> visit(link)
    |> assert_text("Whoa! You aren’t authorized to do that.")
  end
end
