defmodule PicselloWeb.GalleryLive.ClientShow.CartTest do
  @moduledoc false
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    Mox.verify_on_exit!()

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    gallery =
      insert(:gallery, job: insert(:lead, package: insert(:package, download_count: 2)))
      |> Map.put(:credits_available, true)

    insert(:gallery_digital_pricing, %{gallery: gallery, download_count: 2})

    gallery_client =
      insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})

    {:ok, session_token} =
      Picsello.Galleries.build_gallery_session_token(
        gallery,
        gallery.password,
        "testing@picsello.com"
      )

    [
      conn: init_test_session(conn, %{"gallery_session_token" => session_token}),
      gallery: gallery,
      gallery_client: gallery_client,
      cart_path: Routes.gallery_client_show_cart_path(conn, :cart, gallery.client_link_hash)
    ]
  end

  describe "with credit - only digitals" do
    test "does not go to stripe", %{
      conn: conn,
      cart_path: cart_path,
      gallery: gallery,
      gallery_client: gallery_client
    } do
      order = Picsello.Cart.place_product(build(:digital), gallery, gallery_client)

      {:ok, view, _html} = live(conn, cart_path)

      view |> element(".block a", "Continue") |> render_click()

      view
      |> form("form")
      |> render_change(%{"delivery_info" => %{"email" => "brian@example.com", "name" => "Brian"}})

      view |> form("form") |> render_submit()

      assert [%{errors: []}] = Picsello.FeatureCase.FeatureHelpers.run_jobs()

      view
      |> assert_redirect(
        Routes.gallery_client_order_path(
          conn,
          :paid,
          gallery.client_link_hash,
          Picsello.Cart.Order.number(order)
        )
      )
    end
  end

  describe "with multiple products" do
    setup %{conn: conn, gallery: gallery} do
      gallery_client =
        insert(:gallery_client, %{email: "test@picsello.com", gallery_id: gallery.id})

      order =
        for {product, index} <-
              Enum.with_index([insert(:product) | List.duplicate(insert(:product), 2)]),
            reduce: nil do
          _order ->
            Picsello.Cart.place_product(
              build(:cart_product,
                whcc_product: product,
                inserted_at:
                  DateTime.utc_now() |> DateTime.add(index) |> DateTime.truncate(:second)
              ),
              gallery,
              gallery_client
            )
        end

      {:ok, session_token} =
        Picsello.Galleries.build_gallery_session_token(
          gallery,
          gallery.password,
          "test@picsello.com"
        )

      [conn: init_test_session(conn, %{"gallery_session_token" => session_token}), order: order]
    end

    test "groups by product", %{conn: conn, cart_path: cart_path} do
      {:ok, _view, html} = live(conn, cart_path)

      assert [2, 1] =
               html
               |> Floki.parse_document!()
               |> Floki.find("div[data-testid=line-items] > div")
               |> Enum.map(fn div ->
                 div
                 |> Floki.find("div[data-testid^=product-]")
                 |> Enum.count()
               end)
    end

    test "places one whcc order", %{
      conn: conn,
      cart_path: cart_path,
      order: order
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

        assert order |> Picsello.Cart.Order.number() |> to_string() ==
                 Keyword.get(options, :entry_id)

        assert editors |> Enum.map(& &1.id) |> MapSet.new() ==
                 order.products |> Enum.map(& &1.editor_id) |> MapSet.new()

        build(:whcc_editor_export)
      end)
      |> Mox.expect(:create_order, fn _account_ie, _export ->
        {:ok, build(:whcc_order_created)}
      end)

      Picsello.MockPayments
      |> Mox.expect(:create_session, fn _params, _opts ->
        {:ok,
         build(:stripe_session,
           url: "https://stripe.com",
           payment_intent:
             build(:stripe_payment_intent,
               amount: 100,
               description: "i dont know what this will be",
               id: "payment-intent-id",
               status: "requires_payment_method",
               currency: "usd"
             )
         )}
      end)

      {:ok, view, _html} = live(conn, cart_path)
      view |> element(".block a", "Continue") |> render_click()

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

      assert [%{errors: []}] = Picsello.FeatureCase.FeatureHelpers.run_jobs()

      assert_redirect(view, "https://stripe.com")
    end
  end
end
