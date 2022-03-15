defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  setup do
    gallery = insert(:gallery, %{name: "Test Client Wedding"})

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

  test "grid load", %{session: session, gallery: gallery} do
    session
    |> resize_window(600, 1000)
    |> visit("/galleries/#{gallery.id}/settings")
    |> click(css("#regeneratePasswordButton"))
    |> click(link("Share Gallery"))

    assert true ==
             session
             |> has_text?(Query.css("#editor"), "password")

    assert false ==
             session
             |> has_text?(Query.css("#editor"), gallery.password)
  end
end
