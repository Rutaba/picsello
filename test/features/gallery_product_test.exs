defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false

  use Picsello.FeatureCase, async: true

  alias Picsello.Galleries.Photo

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

  test "redirect from galleries", %{
    session: session,
    gallery: %{id: gallery_id},
    products: [%{category_id: category_id, id: product_id} | _]
  } do
    session
    |> visit("/galleries/#{gallery_id}")
    # "Edit this" link is behind bottom bar
    |> force_simulate_click(css(".prod-link#{category_id}"))
    |> assert_path("/galleries/#{gallery_id}/product/#{product_id}")
    |> find(css(".item-content"))
  end

  test "grid load", %{session: session, gallery: %{id: gallery_id, client_link_hash: hash}} do
    photos = :lists.map(fn _ -> :rand.uniform(999_999) end, :lists.seq(1, 22))

    Enum.map(photos, &Map.get(insert_photo(gallery_id, "/images/tmp/#{&1}.png"), :id))

    session
    |> visit("/galleries/#{gallery_id}")

    session
    |> visit("/gallery/#{hash}/login")
    |> fill_in(css("#login_password"), with: "123456")
    |> has_text?("Test Client Wedding")
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
