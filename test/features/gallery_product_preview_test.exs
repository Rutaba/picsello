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

    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    [products: products, photo_ids: photo_ids]
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
    gallery: %{id: gallery_id},
    products: [%{id: product_id, category: category} | _],
    photo_ids: photo_ids
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> click(css("#product-id-#{product_id}"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> assert_has(css("p", text: "#{category.name} preview successfully updated"))
  end
end
