defmodule Picsello.GalleryProductPreviewToggleTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup do
    Mox.verify_on_exit!()
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")

    insert(:user,
      organization: organization,
      stripe_customer_id: "photographer-stripe-customer-id"
    )
    |> onboard!()

    package =
      insert(:package,
        organization: organization,
        download_each_price: ~M[2500]USD,
        buy_all: ~M[5000]USD
      )

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          ),
        use_global: %{watermark: true, expiration: true, digital: true, products: true}
      )

    gallery_digital_pricing = insert(:gallery_digital_pricing, gallery: gallery)

    insert(:watermark, gallery: gallery)
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 3})

    for {%{id: category_id} = category, index} <-
          Enum.with_index(Picsello.Repo.all(Picsello.Category)) do
      preview_photo =
        insert(:photo,
          gallery: gallery,
          preview_url: "/#{category_id}/preview.jpg",
          original_url: "/#{category_id}/original.jpg",
          watermarked_preview_url: "/#{category_id}/watermarked_preview.jpg",
          watermarked_url: "/#{category_id}/watermarked.jpg",
          position: index + 1
        )

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )

      global_gallery_product =
        insert(:global_gallery_product,
          category: category,
          organization: organization,
          markup: 100
        )

      if category.whcc_id == "h3GrtaTf5ipFicdrJ" do
        product = insert(:product, category: category)

        insert(:global_gallery_print_product,
          product: product,
          global_settings_gallery_product: global_gallery_product
        )
      end
    end

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, & &1)
    |> Mox.stub(:get, &{:ok, %{name: &1}})

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "photographer-stripe-customer-id", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [gallery: gallery, organization: organization, package: package, photo_ids: photo_ids, gallery_digital_pricing: gallery_digital_pricing]
  end

  setup :authenticated_gallery_client

  test "Toggle disable product and view in client preview", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_text("Product Previews")
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 0))
    |> find(checkbox("Product enabled to sell", count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 6, at: 0))
    |> find(
      checkbox("Show product preview in gallery", count: 6, at: 0),
      fn checkbox -> refute Element.selected?(checkbox) end
    )
    |> assert_has(css("a[href*='/gallery/#{gallery.client_link_hash}']", text: "Preview gallery"))
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(link("View Gallery"))
    |> assert_text("Test Client Wedding Gallery")
    |> assert_has(css("*[data-testid='products'] li", count: 5))
  end

  test "Toggle disable product in gallery", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_text("Product Previews")
    |> click(css("span", text: "Product enabled to sell", count: 7, at: 0))
    |> find(checkbox("Product enabled to sell", visible: true, count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("span", text: "Show product preview in gallery", count: 6, at: 0))
    |> find(
      checkbox("Show product preview in gallery", visible: true, count: 6, at: 0),
      fn checkbox -> refute Element.selected?(checkbox) end
    )
  end

  test "Toggle disable product preview and product available for purchase", %{
    session: session,
    gallery: %{id: gallery_id} = gallery,
    photo_ids: photo_ids
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_text("Product Previews")
    |> click(css("span", text: "Product enabled to sell", count: 7, at: 0))
    |> click(css("span", text: "Product enabled to sell", count: 7, at: 1))
    |> find(checkbox("Product enabled to sell", visible: true, count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> find(checkbox("Product enabled to sell", visible: true, count: 7, at: 1), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("span", text: "Show product preview in gallery", count: 5, at: 0))
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(link("View Gallery"))
    |> assert_text("Test Client Wedding Gallery")
    |> assert_has(css("*[data-testid='products'] li", count: 5))
    |> scroll_to_bottom()
    |> click(css("#item-#{List.first(photo_ids)}"))
    |> assert_text("Select an option")
    |> find(css("*[data-testid^='product_option']", count: 6), fn options ->
      assert [
               {"Books", "$2,222.00"},
               {"Ornaments", "$2,020.00"},
               {"Loose Prints", "$50,000.00"},
               {"Press Printed Cards", "$77.77"},
               {"Display Products", "$3,939.00"},
               {"Digital Download"}
             ] =
               options
               |> Enum.map(fn option ->
                 option
                 |> find(css("p", count: :any))
                 |> Enum.map(&Element.text/1)
                 |> List.to_tuple()
               end)
    end)
  end

  test "Product Preview, 'edit product preview' is removed", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> take_screenshot()
    |> assert_has(button("Edit product preview", visible: true, count: 7))
    |> find(checkbox("Product enabled to sell", visible: true, count: 7, at: 0), fn checkbox ->
      assert Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 7, at: 0))
    |> assert_has(button("Edit product preview", visible: true, count: 6))
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 1))
    |> assert_has(button("Edit product preview", visible: true, count: 5))
  end
end
