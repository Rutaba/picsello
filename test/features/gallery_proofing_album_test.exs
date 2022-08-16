defmodule Picsello.GalleryProofingAlbumTest do
  use Picsello.FeatureCase, async: true

  import Money.Sigils
  alias Picsello.{Repo, Package}
  alias Picsello.Cart.{Digital, DeliveryInfo}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
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
    proofing_album = insert(:proofing_album, %{gallery_id: gallery.id})

    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    Repo.update_all(Package, set: [download_count: 2])

    [proofing_album: proofing_album]
  end

  feature "Photographer views client selections", %{
    session: session,
    proofing_album: album,
    gallery: gallery
  } do
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 5})
    order = insert(:order,
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
      album: album,
      digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
    )

    session
    |> visit("/galleries/#{gallery.id}/albums/#{album.id}")
    |> assert_has(css("span", text: "#{album.name}"))
    |> assert_has(testid("selection-complete", text: "Client selection complete"))
    |> assert_has(button("Add finals album"))
    |> assert_has(testid("selection-name", text: "Client Selection - #{DateTime.to_date(order.placed_at)}"))
    |> click(css("#toggle_selections"))
    |> assert_has(css(".item", count: 5))
    |> click(css("#toggle_selections"))
    |> assert_has(testid("selection-name", text: "Client Selection - #{DateTime.to_date(order.placed_at)}"))
  end

  feature "Photographer downloads client selections as zip", %{
    session: session,
    proofing_album: album,
    gallery: gallery
  } do
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 5})
    order = insert(:order,
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
      album: album,
      digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
    )
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
    gallery: gallery
  } do
    photo_ids = insert_photo(%{gallery: gallery, album: album, total_photos: 5})
    order = insert(:order,
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
      album: album,
      digitals: [%Digital{photo_id: List.first(photo_ids), price: ~M[0]USD}]
    )
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
end
