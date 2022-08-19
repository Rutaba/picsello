defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true
  import Picsello.TestSupport.ClientGallery

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    [products: products(gallery)]
  end

  def products(gallery, coming_soon \\ false) do
    Enum.map(Picsello.Category.frame_images(), fn frame_image ->
      :category
      |> insert(frame_image: frame_image, coming_soon: coming_soon)
      |> Kernel.then(fn category ->
        insert(:product, category: category)

        insert(:gallery_product,
          category: category,
          gallery: gallery
        )
      end)
    end)
  end

  test "Product Preview render", %{
    session: session,
    gallery: %{id: gallery_id},
    products: products
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images']", count: length(products)))
  end

  test "Product Preview for Non-US photographer", %{
    session: session,
    gallery: gallery
  } do
    Picsello.Repo.update_all(Picsello.Accounts.User,
      set: [
        onboarding: %Picsello.Onboardings.Onboarding{
          state: "Non-US",
          completed_at: DateTime.utc_now()
        }
      ]
    )

    session
    |> visit("/galleries/#{gallery.id}/product-previews")
    |> assert_text("Product ordering is not available in your country yet.")
    |> find(css("*[id^='/images']", count: 0))
  end

  test "Product Preview render with coming soon", %{
    session: session,
    gallery: gallery
  } do
    products(gallery, true)

    session
    |> visit("/galleries/#{gallery.id}/product-previews")
    |> assert_has(css("button", text: "Edit product preview", count: 4))
    |> assert_has(css("button:disabled", text: "Coming soon!", count: 4))
  end

  test "Product Preview, edit product", %{
    session: session,
    gallery: %{id: gallery_id} = gallery,
    products: [%{id: product_id, category: category} | _]
  } do
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> click(css("#product-id-#{product_id}"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "#{category.name} preview successfully updated"))
  end

  test "Product Preview, set first photo of gallery as product previews", %{
    session: session,
    gallery: %{id: gallery_id} = gallery,
    products: products
  } do
    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css("#dragDrop-upload-form span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images']", count: length(products)))

    assert current_path(session) == "/galleries/#{gallery_id}/product-previews"
    insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: length(photo_ids)))
    |> refute_has(css("#dragDrop-upload-form span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images/print.png-album_transparency.png']", count: 1))
  end

    test "Toggle disable product in gallery", %{
      session: session,
      gallery: %{id: gallery_id} = _gallery,
    } do
      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      |> assert_text("Product Previews")
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 0))
      |> find(checkbox("Product enabled to sell", visible: false, count: 4, at: 0), fn checkbox -> refute Element.selected?(checkbox) end)
      |> click(css("label", text: "Show product preview in gallery", count: 3, at: 0))
      |> find(checkbox("Show product preview in gallery", visible: false, count: 3, at: 0), fn checkbox -> refute Element.selected?(checkbox) end)
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
      |> scroll_to_bottom()
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 0))
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 2))
      |> find(checkbox("Product enabled to sell", visible: false, count: 4, at: 0), fn checkbox -> refute Element.selected?(checkbox) end)
      |> click(css("label", text: "Show product preview in gallery", count: 2, at: 0))
      |> find(checkbox("Show product preview in gallery", visible: false, count: 2, at: 0), fn checkbox -> refute Element.selected?(checkbox) end)
      |> assert_has(css("a[href*='/gallery/#{gallery.client_link_hash}']", text: "Preview Gallery"))
      |> visit("/gallery/#{gallery.client_link_hash}")
      |> click(css("a", text: "View Gallery"))
      |> assert_text("Test Client Wedding Gallery")
      |> assert_text("cool shirts")
      |> scroll_into_view(css("Test Client Wedding Gallery"))
    end

    test "Toggle disable product preview and product available for purchase", %{
      session: session,
      gallery: %{id: gallery_id} = gallery
    } do
      session
      |> visit("/galleries/#{gallery_id}/product-previews")
      photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})
      session
      |> assert_text("Product Previews")
      |> scroll_to_bottom()
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 0))
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 2))
      |> click(css("label", text: "Product enabled to sell", count: 4, at: 3))
      |> find(checkbox("Product enabled to sell", visible: false, count: 4, at: 0), fn checkbox -> refute Element.selected?(checkbox) end)
      |> find(checkbox("Product enabled to sell", visible: false, count: 4, at: 2), fn checkbox -> refute Element.selected?(checkbox) end)
      |> find(checkbox("Product enabled to sell", visible: false, count: 4, at: 3), fn checkbox -> refute Element.selected?(checkbox) end)
      |> click(css("label", text: "Show product preview in gallery", count: 1, at: 0))
      |> visit("/gallery/#{gallery.client_link_hash}")
      |> click(css("a", text: "View Gallery"))
      |> assert_text("Test Client Wedding Gallery")
      |> click_photo(1)
      |> assert_text("Select an option")
      |> assert_text("cool shirts")
    end

end
