defmodule Picsello.GalleryProofingAlbumTest do
  use Picsello.FeatureCase, async: true

  import Money.Sigils
  alias Picsello.Cart.{Digital, DeliveryInfo}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})
    photo_ids = insert_photo(%{gallery: gallery, album: proofing_album, total_photos: 5})

    order =
      insert(:order,
        gallery: gallery,
        placed_at: DateTime.utc_now(),
        delivery_info: %DeliveryInfo{
          address: %DeliveryInfo.Address{
            addr1: "661 w lake st",
            city: "Chicago",
            state: "IL",
            zip: "60661"
          }
        },
        album: proofing_album,
        digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
      )

    insert(:proofs_organization_card,
      data: %{order_id: order.id},
      organization_id: order.gallery.job.client.organization_id
    )

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    [proofing_album: proofing_album, order: order]
  end

  feature "Validate preview proofing button", %{
    session: session,
    proofing_album: album,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(css("a[href*='/album/#{album.client_link_hash}']", text: "Preview"))
  end

  feature "Photographer views client selections",
          %{
            session: session,
            proofing_album: album,
            gallery: gallery,
            order: order
          } do
    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(css("span", text: "#{album.name}", count: 3))
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> assert_has(
      testid("selection-name", text: "Client Selection - #{DateTime.to_date(order.placed_at)}")
    )
    |> click(css("#toggle_selections"))
    |> assert_has(css(".item", count: 4))
    |> click(css("#toggle_selections"))
    |> assert_has(
      testid("selection-name", text: "Client Selection - #{DateTime.to_date(order.placed_at)}")
    )
  end

  feature "Delete opt disappears from edit-album as well as from actions in gallery-albums if there is any order",
          %{
            session: session,
            proofing_album: album,
            gallery: gallery
          } do
    session
    |> visit("/galleries/#{gallery.id}/albums")
    |> click(testid("dropdown-actions-#{album.id}"))
    |> refute_has(button("Delete"))
    |> click(button("Go to album settings"))
    |> refute_has(button("Delete"))
  end

  feature "Photographer downloads client selections as zip", %{
    session: session,
    proofing_album: album,
    gallery: gallery,
    order: order
  } do
    link =
      Routes.gallery_downloads_path(
        PicselloWeb.Endpoint,
        :download_all,
        gallery.client_link_hash,
        photo_ids: Enum.map_join(",", order.digitals, fn digital -> digital.photo_id end)
      )

    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> click(css("#meatball-order-#{order.id}"))
    |> find(
      link("Download photos"),
      &assert(Element.attr(&1, "href") =~ link)
    )
  end

  feature "Photographer downloads client selections as .csv", %{
    session: session,
    proofing_album: album,
    gallery: gallery,
    order: order
  } do
    link =
      Routes.gallery_downloads_url(
        PicselloWeb.Endpoint,
        :download_csv,
        gallery.client_link_hash,
        order.number
      )

    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> click(css("#meatball-order-#{order.id}"))
    |> find(
      link("Download as .CSV"),
      &assert(Element.attr(&1, "href") =~ link)
    )
  end

  feature "user receives next up card on home page", %{
    session: session,
    proofing_album: album,
    gallery: gallery,
    order: order
  } do
    csv_link =
      Routes.gallery_downloads_url(
        PicselloWeb.Endpoint,
        :download_csv,
        gallery.client_link_hash,
        order.number
      )

    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> visit("/")
    |> assert_has(css("h1", text: "A client selected their proofs!"))
    |> find(
      link("Download .CSV"),
      &assert(Element.attr(&1, "href") =~ csv_link)
    )
    |> click(link("Go to Proof list"))
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
  end

  feature "gallery card changes when proofing selections are in", %{
    session: session,
    gallery: gallery
  } do
    gallery =
      gallery
      |> Picsello.Galleries.Gallery.update_changeset(%{type: :proofing})
      |> Picsello.Repo.update!()

    session
    |> visit("/jobs/#{gallery.job.id}")
    |> find(testid("card-proofing"))
    |> assert_has(button("View selects"))
  end

  feature "Selected photo-border in proofing-grid disappears on toggle-button off and on", %{
    session: session,
    proofing_album: album,
    gallery: gallery
  } do
    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> click(testid("proofing-grid-item"))
    |> click(css("#toggle_selections"))
    |> refute_has(css("galleryItem > item-border"))
    |> click(testid("proofing-grid-item"))
    |> click(css("#toggle_selections"))
    |> refute_has(css("galleryItem > item-border"))
  end
end
