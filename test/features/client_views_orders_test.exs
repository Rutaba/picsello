defmodule Picsello.ClientViewsOrdersTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated_gallery_client

  feature "no orders", %{
    session: session
  } do
    session
    |> click(link("My orders"))
    |> assert_text("ordered anything")
  end
end