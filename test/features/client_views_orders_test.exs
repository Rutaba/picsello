defmodule Picsello.ClientViewsOrdersTest do
  use Picsello.FeatureCase, async: true
  use Oban.Testing, repo: Picsello.Repo
  import Money.Sigils
  alias Picsello.Orders

  setup do
    Picsello.PhotoStorageMock
    |> Mox.stub(:get, fn _ -> {:error, nil} end)
    |> Mox.stub(:path_to_url, & &1)

    :ok
  end

  setup do
    gallery = insert(:gallery, job: insert(:lead, package: insert(:package)))
    gallery_client =
      insert(:gallery_client, %{email: "client-1@example.com", gallery_id: gallery.id})

    gallery_digital_pricing =
      insert(:gallery_digital_pricing, %{gallery: gallery, download_count: 0})

    [
      gallery: gallery,
      gallery_digital_pricing: gallery_digital_pricing,
      gallery_client: gallery_client
    ]
  end

  setup :authenticated_gallery_client

  feature "no orders", %{
    session: session
  } do
    session
    |> click(css("a", text: "View Gallery"))
    |> click(link("My orders"))
    |> assert_text("ordered anything")
  end

  feature "an order - shows delivery details", %{
    session: session,
    gallery: gallery,
    gallery_client: gallery_client
  } do
    order =
      insert(:order,
        gallery: gallery,
        gallery_client: gallery_client,
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
                editor_ids: ["editor_id"],
                total: ~M[500]USD
              )
          )
      )

    Mox.stub(Picsello.MockWHCCClient, :webhook_validate, fn _, _ -> %{"isValid" => true} end)

    session
    |> visit(
      Routes.gallery_client_order_path(
        PicselloWeb.Endpoint,
        :show,
        gallery.client_link_hash,
        Orders.number(order)
      )
    )
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

  def stub_storage() do
    Picsello.PhotoStorageMock
    |> Mox.stub(:initiate_resumable, fn _, _ ->
      {:ok, %Tesla.Env{status: 200, headers: [{"location", "https://example.com"}]}}
    end)
    |> Mox.stub(:continue_resumable, fn _, _, _ ->
      {:ok, %Tesla.Env{status: 200}}
    end)
  end

  def insert_order(gallery, gallery_client) do
    order =
      insert(:order,
        gallery: gallery,
        gallery_client: gallery_client,
        placed_at: DateTime.utc_now(),
        delivery_info: %Picsello.Cart.DeliveryInfo{}
      )

    insert(:digital,
      order: order,
      photo: insert(:photo, gallery: gallery, original_url: image_url())
    )

    order
  end

  feature "order list - shows download status", %{
    session: session,
    gallery: gallery,
    gallery_client: gallery_client
  } do
    order = insert_order(gallery, gallery_client)
    stub_storage()

    session
    |> visit(
      Routes.gallery_client_order_path(
        PicselloWeb.Endpoint,
        :show,
        gallery.client_link_hash,
        Orders.number(order)
      )
    )
    |> assert_text("Preparing Download")

    assert_enqueued(worker: Picsello.Workers.PackDigitals)

    assert [] == Enum.flat_map(run_jobs(), & &1.errors)

    session
    |> assert_has(link("Download photos"))
  end

  feature "order details - shows download status", %{
    session: session,
    gallery: gallery,
    gallery_client: gallery_client
  } do
    order = insert_order(gallery, gallery_client)
    stub_storage()

    session
    |> visit(
      Routes.gallery_client_order_path(
        PicselloWeb.Endpoint,
        :show,
        gallery.client_link_hash,
        Orders.number(order)
      )
    )
    |> assert_has(css("h3", text: "Order number #{Orders.number(order)}"))
    |> assert_text("Preparing Download")

    assert [] == Enum.flat_map(run_jobs(), & &1.errors)

    assert_has(session, link("Download photos"))
  end
end
