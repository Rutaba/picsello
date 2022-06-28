defmodule Picsello.GalleryPhotosDownloadTest do
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
    gallery: %{id: gallery_id, client_link_hash: client_link_hash},
    photo_ids: photo_ids
  } do
    link =
      Routes.gallery_downloads_path(
        PicselloWeb.Endpoint,
        :download_all,
        client_link_hash,
        photo_ids: stringify(photo_ids)
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
    link =
      Routes.gallery_downloads_path(
        PicselloWeb.Endpoint,
        :download_photo,
        client_link_hash,
        List.first(photo_ids)
      )

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> force_simulate_click(css("#meatball-photo-#{List.first(photo_ids)}"))
    |> find(
      css("#download-photo-#{List.first(photo_ids)}"),
      &assert(Element.attr(&1, "href") =~ link)
    )
  end

  test "render error 403 if unauthorized user", %{
    session: session,
    gallery: %{id: gallery_id}
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
        photo_ids: stringify(photo_ids)
      )

    session
    |> visit(link)
    |> assert_text("Whoa! You aren’t authorized to do that.")

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> click(css("#select"))
    |> click(button("All"))
    |> click(css("#actions"))
    |> click(css("a", text: "Download photos"))
    |> assert_has(css("p", text: "proper permissions to do that action.", count: 0))
  end

  def stringify(photo_ids) do
    photo_ids |> inspect() |> String.replace(~r'[\[\]]', "")
  end
end
