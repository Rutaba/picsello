defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.Galleries.Photo

  setup do
    gallery = insert(:gallery, %{name: "Test Client Wedding"})

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

    insert(:photo, gallery: gallery)

    [gallery: gallery, products: products]
  end

  setup :onboarded
  setup :authenticated

  test "Product Preview render", %{
    session: session,
    gallery: %{id: gallery_id}
  } do
    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> assert_has(css("#photo", count: 3))
  end

  test "Product Preview, edit product", %{
    session: session,
    gallery: %{id: gallery_id},
    products: [%{id: product_id} | _]
  } do
    count = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 3))

    photo_ids =
      Enum.map(count, fn _ ->
        Map.get(insert_photo(gallery_id, "/images/print.png"), :id)
      end)

    session
    |> visit("/galleries/#{gallery_id}/product-previews")
    |> force_simulate_click(css("#productId#{product_id}"))
    |> click(css("#photo-#{List.first(photo_ids)}"))
    |> click(button("Save"))
    |> find(css("#photo#{List.first(photo_ids)}"))
  end

  def insert_photo(gallery_id, photo_url) do
    insert(%Photo{
      gallery_id: gallery_id,
      preview_url: photo_url,
      original_url: photo_url,
      name: photo_url,
      position: 1
    })
  end
end
