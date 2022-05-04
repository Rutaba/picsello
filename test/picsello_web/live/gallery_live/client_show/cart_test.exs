defmodule PicselloWeb.GalleryLive.ClientShow.CartTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    gallery = insert(:gallery)

    {:ok, session_token} =
      Picsello.Galleries.build_gallery_session_token(gallery, gallery.password)

    [
      conn: init_test_session(conn, %{"gallery_session_token" => session_token}),
      gallery: gallery,
      cart_path: Routes.gallery_client_show_cart_path(conn, :cart, gallery.client_link_hash)
    ]
  end

  test "groups by product", %{conn: conn, gallery: gallery, cart_path: cart_path} do
    cart_products =
      for {%{whcc_id: product_id}, index} <-
            Enum.with_index([insert(:product) | List.duplicate(insert(:product), 2)]) do
        build(:cart_product, product_id: product_id, created_at: index)
      end

    insert(:order, gallery: gallery, products: cart_products)

    {:ok, _view, html} = live(conn, cart_path)

    assert [2, 1, 0] =
             html
             |> Floki.parse_document!()
             |> Floki.find("div[data-testid=line-items] > div")
             |> Enum.map(fn div ->
               div
               |> Floki.find("div[data-testid^=product-]")
               |> Enum.count()
             end)
  end
end
