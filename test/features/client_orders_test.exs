defmodule Picsello.ClientOrdersTest do
  use Picsello.FeatureCase, async: false
  
  setup :authenticated_gallery_client
  setup %{gallery: gallery} do
    whcc_product = insert(:product)
    cart_products = Enum.map(1..3, fn _ -> build(:ordered_cart_product, %{product_id: whcc_product.whcc_id}) end)
    IO.inspect cart_products
    
    [order: insert(:confirmed_order, %{gallery_id: gallery.id, products: cart_products})]
  end
  feature "client reviews the placed order", %{session: session, gallery: gallery, order: order} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/orders/#{order.id}")
    |> assert_text("My orders")
    |> assert_text("Order number #{order.number}")
    |> assert_text("Your order will be sent to:")
    |> assert_text(order.delivery_info.name)
    |> assert_text(order.delivery_info.address.addr1)
    |> assert_text(order.delivery_info.address.city <> ", " <> order.delivery_info.address.state <> " " <> order.delivery_info.address.zip)
  end
end
