defmodule Picsello.GalleryProductPreviewTest do
  use Picsello.FeatureCase, async: true

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
    |> assert_has(css("canvas", count: 3))
  end

  test "Product Preview, edit product", %{
    session: session,
    gallery: gallery
  } do
    photo_url = "/images/different_preview.png"

    _photos =
      insert_list(3, :photo,
        gallery: gallery,
        name: photo_url,
        original_url: photo_url,
        preview_url: photo_url
      )

    session
    |> visit("/galleries/#{gallery.id}/product-previews")
    |> click(button("Edit this", count: 3, at: 0))
    |> within_modal(fn modal ->
      modal
      |> click(css("#muuri-grid .galleryItem", count: 4, at: 3))
      |> click(css("button:not(:disabled)", text: "Save"))
    end)
    |> find(css("canvas", count: 3), fn canvases ->
      assert photo_url in Enum.map(
               canvases,
               &(&1
                 |> Element.attr("data-config")
                 |> Jason.decode!()
                 |> Map.get("preview"))
             )
    end)
  end
end
