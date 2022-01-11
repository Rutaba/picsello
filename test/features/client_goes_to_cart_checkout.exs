defmodule Picsello.ClientGoesToCartCheckoutTest do
  use Picsello.FeatureCase, async: false
  alias Picsello.Cart
  import Mox

  setup :set_mox_global
  setup :authenticated_gallery_client

  setup do
    [whcc_product: insert(:product)]
  end

  setup %{gallery: gallery, whcc_product: whcc_product} do
    Picsello.MockWHCCClient
    |> Mox.stub(:create_order, fn _, _, _ -> build(:whcc_order_created) end)

    Picsello.MockPayments
    |> Mox.stub(:checkout_link, fn _, t ->
      {:ok, %{link: "https://example.com/stripe-checkout"}}
    end)

    Enum.each(1..3, fn _ ->
      cart_product = build(:cart_product, %{product_id: whcc_product.whcc_id})
      Cart.place_product(cart_product, gallery.id)
    end)

    :ok
  end

  feature "client goes to checkout", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> click(button("Continue"))
    |> click(button("Check out with Stripe"))
    |> assert_url_contains("stripe-checkout")
  end
end
