defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true

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
    |> assert_has(css("button", text: "Edit this", count: 4))
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
    |> assert_has(css("#dragDrop-upload-form-#{gallery_id} span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images']", count: length(products)))

    assert current_path(session) == "/galleries/#{gallery_id}/product-previews"
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: length(photo_ids)))
    |> refute_has(css("#dragDrop-upload-form-#{gallery_id} span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images/print.png-album_transparency.png']", count: 1))
  end
end
