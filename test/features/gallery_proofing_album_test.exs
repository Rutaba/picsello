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

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    [proofing_album: proofing_album, order: order]
  end

  feature "Photographer views client selections", %{
    session: session,
    proofing_album: album,
    gallery: gallery,
    order: order
  } do
    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(css("span", text: "#{album.name}", count: 3))
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> assert_has(button("Add finals album"))
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
        photo_ids: Enum.map(order.digitals, fn digital -> digital.photo_id end) |> Enum.join(",")
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
    gallery: %{job: job}
  } do
    session
    |> visit("/jobs/#{job.id}")
    |> find(testid("card-Gallery"))
    |> assert_has(css("p", text: "Your client's prooflist is in!"))
    |> assert_has(button("Go to gallery"))
  end
end
