defmodule Picsello.ClientIndexTest do
  use Picsello.FeatureCase, async: true

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
