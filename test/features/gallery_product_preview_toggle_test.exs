defmodule Picsello.GalleryProductPreviewToggleTest do
  use Picsello.FeatureCase, async: true
  import Picsello.TestSupport.ClientGallery
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

    for category <- Picsello.Repo.all(Picsello.Category) do
      preview_photo = insert(:photo, gallery: gallery, preview_url: "fake.jpg")

      insert(:gallery_product,
        category: category,
        preview_photo: preview_photo,
        gallery: gallery
      )
    end

    [gallery: gallery]
  end

  test "Toggle disable product in gallery", %{
    session: session,
    gallery: %{id: gallery_id} = _gallery
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_text("Product Previews")
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 0))
    |> find(checkbox("Product enabled to sell", visible: false, count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 6, at: 0))
    |> find(
      checkbox("Show product preview in gallery", visible: false, count: 6, at: 0),
      fn checkbox -> refute Element.selected?(checkbox) end
    )
  end

  test "Toggle disable product and view in client preview", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")

    insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> assert_text("Product Previews")
    |> take_screenshot()
    |> scroll_to_bottom()
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 0))
    |> find(checkbox("Product enabled to sell", visible: false, count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 6, at: 1))
    |> find(
      checkbox("Show product preview in gallery", visible: false, count: 6, at: 1),
      fn checkbox -> refute Element.selected?(checkbox) end
    )
    |> assert_has(css("a[href*='/gallery/#{gallery.client_link_hash}']", text: "Preview Gallery"))
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(link("View Gallery"))
    |> assert_text("Test Client Wedding Gallery")
    |> assert_has(css("*[data-testid='products'] li", count: 5))
  end

  test "Toggle disable product preview and product available for purchase", %{
    session: session,
    gallery: %{id: gallery_id} = gallery
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")

    insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> assert_text("Product Previews")
    |> scroll_to_bottom()
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 0))
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 2))
    |> click(css("label", text: "Product enabled to sell", count: 7, at: 3))
    |> find(checkbox("Product enabled to sell", visible: false, count: 7, at: 0), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> find(checkbox("Product enabled to sell", visible: false, count: 7, at: 2), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> find(checkbox("Product enabled to sell", visible: false, count: 7, at: 3), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
    |> click(css("label", text: "Show product preview in gallery", count: 4, at: 0))
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(link("View Gallery"))
    |> assert_text("Test Client Wedding Gallery")
    |> assert_has(css("*[data-testid='products'] li", count: 3))
    |> scroll_to_bottom()
    |> click_photo(1)
    |> assert_text("Select an option")
    # fails here
    |> find(css("*[data-testid^='product_option']", count: 5), fn options ->
      assert [
               {"Albums", "$55.00"},
               {"Loose Prints", "$25.00"},
               {"Press Printed Cards", "$5.00"},
               {"Display Products", "$80.00"},
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
end
