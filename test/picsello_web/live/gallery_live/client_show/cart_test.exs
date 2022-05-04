defmodule PicselloWeb.GalleryLive.ClientShow.CartTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    Mox.verify_on_exit!()

    gallery = insert(:gallery)

    {:ok, session_token} =
      Picsello.Galleries.build_gallery_session_token(gallery, gallery.password)

    [
      conn: init_test_session(conn, %{"gallery_session_token" => session_token}),
      gallery: gallery,
      cart_path: Routes.gallery_client_show_cart_path(conn, :cart, gallery.client_link_hash)
    ]
  end

  describe "with multiple products" do
    setup %{gallery: gallery} do
      cart_products =
        for {%{whcc_id: product_id}, index} <-
              Enum.with_index([insert(:product) | List.duplicate(insert(:product), 2)]) do
          build(:cart_product, product_id: product_id, created_at: index)
        end

      [order: insert(:order, gallery: gallery, products: cart_products)]
    end

    test "groups by product", %{conn: conn, cart_path: cart_path} do
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

    test "places one whcc order when multiple products", %{
      conn: conn,
      cart_path: cart_path,
      order: %{products: products}
    } do
      Picsello.MockWHCCClient
      |> Mox.expect(:editors_export, fn _account_id, editors, options ->
        assert %Picsello.Cart.DeliveryInfo{
                 address: %Picsello.Cart.DeliveryInfo.Address{
                   addr1: "661 w lake st",
                   addr2: nil,
                   city: "Chicago",
                   country: "US",
                   state: "IL",
                   zip: "60661"
                 },
                 email: "brian@example.com",
                 name: "Brian"
               } = Keyword.get(options, :address)

        assert Enum.map(editors, & &1.id) == Enum.map(products, &Picsello.Cart.CartProduct.id/1)
        build(:whcc_editor_export)
      end)
      |> Mox.expect(:create_order, fn _account_ie, _export ->
        build(:whcc_order_created)
      end)

      Picsello.MockPayments
      |> Mox.expect(:create_session, fn _params, _opts -> {:ok, %{url: "https://stripe.com"}} end)

      {:ok, view, _html} = live(conn, cart_path)
      view |> element(".block button", "Continue") |> render_click()

      view
      |> form("form")
      |> render_change(%{
        "delivery_info" => %{
          "email" => "brian@example.com",
          "name" => "Brian",
          "address" => %{
            "addr1" => "661 w lake st",
            "city" => "Chicago",
            "zip" => "60661",
            "state" => "IL"
          }
        }
      })

      view |> form("form") |> render_submit()

      assert_redirect(view, "https://stripe.com")
    end
  end
end
