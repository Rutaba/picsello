defmodule Picsello.GalleryProductPreviewToggleTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Accounts.User}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{user: user} do
    user = user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "cus_123", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [user: user]
  end

  setup do
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    for category <- Picsello.Repo.all(Picsello.Category) do
      preview_photo = insert(:photo, gallery: gallery, preview_url: "fake.jpg")

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )
    end

    [gallery: gallery, photo_ids: photo_ids]
  end

  test "Toggle disable product and view in client preview", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_text("Product Previews")
    |> scroll_to_bottom()
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 0))
    |> find(checkbox("Product enabled to sell", count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 6, at: 0))
    |> find(
      checkbox("Show product preview in gallery", count: 6, at: 0),
      fn checkbox -> refute Element.selected?(checkbox) end
    )
    |> assert_has(css("a[href*='/gallery/#{gallery.client_link_hash}']", text: "Preview Gallery"))
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
    |> scroll_to_bottom()
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
               {"Albums", "$52.00"},
               {"Loose Prints", "$2.00"},
               {"Press Printed Cards", "$2.00"},
               {"Display Products", "$78.00"},
               {"Digital Download", "$25.00"}
             ] =
               options
               |> Enum.map(fn option ->
                 option
                 |> find(css("p", count: 2))
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
