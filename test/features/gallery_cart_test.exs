defmodule Picsello.GalleryCartTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true
  alias Picsello.{Cart, Repo}
  alias Cart.Order
  import Money.Sigils

  setup do
    Mox.stub(Picsello.PhotoStorageMock, :get, fn _ -> {:error, nil} end)

    gallery =
      insert(:gallery,
        job: insert(:lead, package: insert(:package, download_each_price: ~M[3500]USD))
      )
      |> Repo.preload(job: [client: [organization: :user]])

    gallery_digital_pricing =
      insert(:gallery_digital_pricing, %{
        gallery: gallery,
        email_list: [gallery.job.client.email],
        download_count: 0,
        print_credits: Money.new(0)
      })

    gallery =
      Map.put(
        gallery,
        :credits_available,
        gallery.job.client.email in gallery_digital_pricing.email_list
      )

    gallery_client =
      insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})

    [
      gallery: gallery,
      gallery_client: gallery_client,
      gallery_digital_pricing: gallery_digital_pricing
    ]
  end

  setup :authenticated_gallery_client

  def fill_gallery_cart(gallery, gallery_client) do
    whcc_product =
      insert(:product,
        whcc_name: "poster",
        attribute_categories: [
          %{"_id" => "size", "attributes" => [%{"id" => "20x30", "name" => "20 by 30 inches"}]}
        ]
      )

    cart_product = build(:cart_product, whcc_product: whcc_product)

    cart_product
    |> Cart.place_product(gallery, gallery_client)
    |> preload_order_items()
  end

  feature "redirects to gallery if cart is empty", %{session: session, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}")
    |> assert_text(gallery.name)
  end

  feature "shows cart info", %{session: session, gallery: gallery, gallery_client: gallery_client} do
    %{products: [%{price: price} = cart_product]} =
      order = fill_gallery_cart(gallery, gallery_client)

    session
    |> visit("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_path("/gallery/#{gallery.client_link_hash}/cart")
    |> assert_text("Cart & Shipping Review")
    |> assert_text("20 by 30 inches poster")
    |> assert_text(Money.to_string(price))
    |> assert_has(css("button", count: 1, text: "Edit"))
    |> assert_has(css("button", count: 1, text: "Delete"))
    |> assert_has(
      definition("Subtotal",
        text: order |> preload_order_items() |> Order.total_cost() |> to_string()
      )
    )
    |> assert_has(testid("product-#{cart_product.editor_id}"))
  end

  feature "continue", %{session: session, gallery: gallery, gallery_client: gallery_client} do
    fill_gallery_cart(gallery, gallery_client)

    Mox.stub(Picsello.MockWHCCClient, :create_order, fn _account_id, _export ->
      build(:whcc_order_created, total: ~M[0]USD)
    end)

    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("a", text: "View Gallery"))
    |> click(link("cart"))
    |> click(link("Continue"))
    |> fill_in(text_field("Email address"), with: "client@example.com")
    |> fill_in(text_field("Name"), with: "brian")
    |> fill_in(text_field("Shipping address"), with: "123 w main st")
    |> fill_in(text_field("delivery_info_address_city"), with: "Tulsa")
    |> click(option("OK"))
    |> fill_in(text_field("delivery_info_address_zip"), with: "74104")
    |> wait_for_enabled_submit_button()
    |> assert_has(button("Check out with Stripe"))
  end

  defp preload_order_items(order) do
    order |> Repo.preload([:digitals, products: :whcc_product], force: true)
  end
end
