defmodule Picsello.GalleryCartTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Cart

  setup :authenticated_gallery_client

  def fill_gallery_cart(gallery) do
    whcc_product =
      insert(:product,
        whcc_name: "poster",
        attribute_categories: [
          %{"_id" => "size", "attributes" => [%{"id" => "20x30", "name" => "20 by 30 inches"}]}
        ]
      )

    cart_product = build(:cart_product, %{product_id: whcc_product.whcc_id})
    Cart.place_product(cart_product, gallery.id)
  end

  feature "redirects to gallery if cart is empty", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}")
  end

  feature "shows cart info", %{session: session, gallery: gallery} do
    order = fill_gallery_cart(gallery)
    cart_product = Enum.at(order.products, 0)

    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_text("Cart Review")
    |> assert_text("20 by 30 inches poster")
    |> assert_text(Money.to_string(cart_product.price))
    |> assert_has(css("button", count: 1, text: "Edit"))
    |> assert_has(css("button", count: 1, text: "Delete"))
    |> assert_text("Subtotal: " <> Money.to_string(order.subtotal_cost))
    |> assert_has(testid("product-#{cart_product.editor_details.editor_id}"))
  end

  feature "continue", %{session: session, gallery: gallery} do
    fill_gallery_cart(gallery)

    Mox.stub(Picsello.MockWHCCClient, :create_order, fn _account_id, _editor_id, _opts ->
      %Picsello.WHCC.Order.Created{total: "0"}
    end)

    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(link("cart"))
    |> click(button("Continue"))
    |> fill_in(text_field("Email address"), with: "client@example.com")
    |> fill_in(text_field("Name"), with: "brian")
    |> fill_in(text_field("Shipping address"), with: "123 w main st")
    |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
    |> click(option("OK"))
    |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
    |> wait_for_enabled_submit_button()
    |> click(button("Continue"))
    |> assert_has(button("Check out with Stripe"))
  end
end
