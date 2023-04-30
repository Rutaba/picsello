defmodule Picsello.ClientIndexTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup do
    Picsello.PhotoStorageMock
    |> Mox.stub(:get, fn _ -> {:ok, %{name: "example.png"}} end)
    |> Mox.stub(:path_to_url, & &1)

    gallery =
      insert(:gallery,
        job: insert(:lead, package: insert(:package, download_each_price: ~M[3500]USD))
      )

    gallery_digital_pricing = insert(:gallery_digital_pricing, %{gallery: gallery, download_count: 0})

    [gallery: gallery, gallery_digital_pricing: gallery_digital_pricing]
  end

  setup :authenticated_gallery_client

  feature "Client gallery, cover photo cookie test", %{session: session} do
    gallery_url = session |> current_url()

    session
    |> assert_has(testid("gallery-client", count: 0))
    |> assert_has(css("#gallery-conver-photo", count: 1))
    # iPhone 8+
    |> resize_window(414, 736)
    |> assert_has(testid("gallery-client", count: 1))
    |> refute_has(css("a", text: "View Gallery"))
    |> assert_has(css("#gallery-conver-photo", count: 1))
    |> resize_window(1280, 900)
    |> click(css("a", text: "View Gallery"))
    |> assert_has(testid("gallery-client", count: 1))
    |> assert_has(css("#gallery-conver-photo", count: 0))
    |> visit(gallery_url)
    |> assert_has(css("#gallery-conver-photo", count: 0))
    |> assert_has(testid("gallery-client", count: 1))
  end
end
