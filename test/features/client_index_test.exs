defmodule Picsello.ClientIndexTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated_gallery_client

  feature "Client gallery, cover photo cookie test", %{session: session} do
    gallery_url = session |> current_url()

    session
    |> refute_has(css("#gallery-client", count: 1))
    |> assert_has(css("#gallery-conver-photo", count: 1))
    |> click(css("a", text: "View Gallery"))
    |> assert_has(css("#gallery-client", count: 1))
    |> assert_has(css("#gallery-conver-photo", count: 0))
    |> visit(gallery_url)
    |> assert_has(css("#gallery-conver-photo", count: 0))
    |> assert_has(css("#gallery-client", count: 1))
  end
end
