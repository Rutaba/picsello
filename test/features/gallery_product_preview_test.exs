defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    products =
      Enum.map(Picsello.Category.frame_images(), fn frame_image ->
        :category
        |> insert(frame_image: frame_image)
        |> Kernel.then(fn category ->
          insert(:product, category: category)

          insert(:gallery_product,
            category: category,
            gallery: gallery
          )
        end)
      end)

    [products: products]
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
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    session
    |> visit("/galleries/#{gallery_id}/photos")
    |> assert_has(css(".item", count: length(photo_ids)))
    |> refute_has(css("#dragDrop-upload-form span", text: "Drag your images or"))
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> find(css("*[id^='/images/print.png-album_transparency.png']", count: 1))
  end
end
