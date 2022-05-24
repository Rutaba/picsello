defmodule Picsello.GalleryCartTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Cart, Repo}
  alias Cart.Order
  import Money.Sigils

  setup :authenticated_gallery_client

  def fill_gallery_cart(gallery) do
    whcc_product =
      insert(:product,
        whcc_name: "poster",
        attribute_categories: [
          %{"_id" => "size", "attributes" => [%{"id" => "20x30", "name" => "20 by 30 inches"}]}
        ]
      )

    cart_product = build(:cart_product, whcc_product: whcc_product)

    Cart.place_product(cart_product, gallery.id)
    |> Repo.preload(:digitals, products: :whcc_product)
  end

  feature "redirects to gallery if cart is empty", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}")
  end

  feature "shows cart info", %{session: session, gallery: gallery} do
    %{products: [%{price: price} = cart_product]} = order = fill_gallery_cart(gallery)

    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_text("Cart Review")
    |> assert_text("20 by 30 inches poster")
    |> assert_text(Money.to_string(price))
    |> assert_has(css("button", count: 1, text: "Edit"))
    |> assert_has(css("button", count: 1, text: "Delete"))
    |> assert_has(definition("Subtotal", text: order |> Order.total_cost() |> to_string()))
    |> assert_has(testid("product-#{cart_product.editor_id}"))
  end

  feature "continue", %{session: session, gallery: gallery} do
    fill_gallery_cart(gallery)

    Mox.stub(Picsello.MockWHCCClient, :create_order, fn _account_id, _export ->
      build(:whcc_order_created, total: ~M[0]USD)
    end)

    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("a", text: "View Gallery"))
    |> click(link("cart"))
    |> click(button("Continue"))
    |> fill_in(text_field("Email address"), with: "client@example.com")
    |> fill_in(text_field("Name"), with: "brian")
    |> fill_in(text_field("Shipping address"), with: "123 w main st")
    |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
    |> click(option("OK"))
    |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
    |> wait_for_enabled_submit_button()
    |> assert_has(button("Check out with Stripe"))
  end
end
