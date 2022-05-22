defmodule Picsello.ClientViewsOrdersTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup :authenticated_gallery_client

  feature "no orders", %{
    session: session
  } do
    session
    |> click(css("a", text: "View Gallery"))
    |> click(css("a", text: "My orders"))
    |> assert_text("ordered anything")
  end

  feature "an order", %{session: session, gallery: gallery} do
    insert(:order,
      gallery: gallery,
      placed_at: DateTime.utc_now(),
      delivery_info: %Picsello.Cart.DeliveryInfo{
        address: %Picsello.Cart.DeliveryInfo.Address{
          addr1: "661 w lake st",
          city: "Chicago",
          state: "IL",
          zip: "60661"
        }
      },
      products:
        build_list(1, :cart_product,
          whcc_product: insert(:product),
          editor_id: "editor_id"
        ),
      whcc_order:
        build(:whcc_order_created,
          entry_id: "123",
          orders:
            build_list(1, :whcc_order_created_order,
              sequence_number: 69,
              editor_id: "editor_id",
              total: ~M[500]USD
            )
        )
    )

    Mox.stub(Picsello.MockWHCCClient, :webhook_validate, fn _, _ -> %{"isValid" => true} end)

    session
    |> click(css("a", text: "View Gallery"))
    |> click(link("My orders"))
    |> click(link("View details"))
    |> assert_text("We’ll provide tracking info once your item ships")
    |> post(
      PicselloWeb.Router.Helpers.whcc_webhook_path(PicselloWeb.Endpoint, :webhook),
      Jason.encode!(%{
        "ShippingInfo" => [
          %{
            "Carrier" => "FedEx",
            "ShipDate" => "2018-12-31T06:18:38-06:00",
            "TrackingNumber" => "512376671311227",
            "TrackingUrl" => "http://www.fedex.com/Tracking?tracknumbers=512376671311227",
            "Weight" => 0.35
          }
        ],
        "Event" => "Shipped",
        "EntryId" => "123",
        "SequenceNumber" => "69"
      }),
      [{"whcc-signature", "Love, whcc"}]
    )
    |> visit(current_path(session))
    |> assert_text("Item shipped:")
  end
end
