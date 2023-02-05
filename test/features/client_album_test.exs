defmodule Picsello.ClientAlbumTest do
  use Picsello.FeatureCase, async: true

  import Money.Sigils
  alias Picsello.Galleries

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")
    insert(:user, organization: organization)
    package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          )
      )

    album = insert(:album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 5})

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    [gallery: gallery, album: album, photo_ids: photo_ids]
  end

  setup :authenticated_gallery_client

  feature "Client gallery, albums render test", %{session: session} do
    session
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css(".albumPreview", count: 1))
    |> refute_has(css("#muuri-grid", count: 1))
  end

  feature "Client gallery, album test", %{session: session, album: album, photo_ids: photo_ids} do
    session
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css(".albumPreview", count: 1))
    |> refute_has(css("#muuri-grid", count: 1))
    |> click(css(".albumPreview"))
    |> click(css("h3", text: album.name))
    |> assert_has(css("#muuri-grid", count: 1))
    |> assert_has(css(".item", count: Enum.count(photo_ids)))
    |> click(css("#img-#{List.first(photo_ids)}"))
    |> within_modal(fn modal ->
      modal
      |> click(button("Add to cart"))
    end)
  end

  feature "Client gallery could not add to cart when gallery disabled", %{
    session: session,
    album: album,
    gallery: gallery,
    photo_ids: photo_ids
  } do
    {:ok, _gallery} = Galleries.update_gallery(gallery, %{status: "disabled"})

    session
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css(".albumPreview", count: 1))
    |> refute_has(css("#muuri-grid", count: 1))
    |> click(css(".albumPreview"))
    |> click(css("h3", text: album.name))
    |> assert_has(css("#muuri-grid", count: 1))
    |> assert_has(css(".item", count: Enum.count(photo_ids)))
    |> click(css("#img-#{List.first(photo_ids)}"))
    |> refute_has(button("Add to cart"))
  end
end
